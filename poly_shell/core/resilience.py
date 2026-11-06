"""Resilience, fault-tolerance and defensive execution patterns for ALPORA.

Implements Higher-Order Functions (HOF), decorators, and defensive algorithms:
- Exponential Backoff Retry
- Circuit Breaker Pattern (CLOSED -> OPEN -> HALF-OPEN)
- Debounce and Rate-Limiting Throttler
- Thread-safe LRU Cache with Time-To-Live (TTL)
- Safe Lambda / Callable wrappers with fallback values
"""
from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from functools import wraps
import logging
import threading
import time
from typing import Any, Callable, Sequence, TypeVar

T = TypeVar("T")
logger = logging.getLogger("poly_shell.resilience")


# ============================================================================
# 1. Higher-Order Functions: Retry with Exponential Backoff
# ============================================================================

def retry(
    max_attempts: int = 3,
    backoff_factor: float = 1.5,
    initial_delay: float = 0.05,
    max_delay: float = 2.0,
    handled_exceptions: Sequence[type[Exception]] = (Exception,),
    fallback: Any = None,
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """HOF decorator that retries a callable with exponential backoff and jitter."""

    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            delay = initial_delay
            last_err: Exception | None = None
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except tuple(handled_exceptions) as exc:
                    last_err = exc
                    if attempt == max_attempts:
                        break
                    time.sleep(min(delay, max_delay))
                    delay *= backoff_factor
            if fallback is not None:
                return fallback
            if last_err is not None:
                raise last_err
            return fallback

        return wrapper

    return decorator


# ============================================================================
# 2. Circuit Breaker Pattern (Fault-Isolation Algorithm)
# ============================================================================

@dataclass
class CircuitBreakerStats:
    state: str  # "CLOSED", "OPEN", "HALF-OPEN"
    failure_count: int
    success_count: int
    last_failure_time: float


class CircuitBreaker:
    """Protects shell from cascade failures when an external system daemon hangs or crashes."""

    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF-OPEN"

    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        recovery_timeout: float = 15.0,
        half_open_success_threshold: int = 2,
    ) -> None:
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_success_threshold = half_open_success_threshold

        self._state = self.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._last_failure_time = 0.0
        self._lock = threading.Lock()

    @property
    def state(self) -> str:
        with self._lock:
            if self._state == self.OPEN:
                if (time.monotonic() - self._last_failure_time) >= self.recovery_timeout:
                    self._state = self.HALF_OPEN
                    self._success_count = 0
            return self._state

    def record_success(self) -> None:
        with self._lock:
            if self._state == self.HALF_OPEN:
                self._success_count += 1
                if self._success_count >= self.half_open_success_threshold:
                    self._state = self.CLOSED
                    self._failure_count = 0
            elif self._state == self.CLOSED:
                self._failure_count = 0

    def record_failure(self) -> None:
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.monotonic()
            if self._state == self.HALF_OPEN or self._failure_count >= self.failure_threshold:
                self._state = self.OPEN

    def stats(self) -> CircuitBreakerStats:
        with self._lock:
            return CircuitBreakerStats(
                state=self._state,
                failure_count=self._failure_count,
                success_count=self._success_count,
                last_failure_time=self._last_failure_time,
            )

    def __call__(self, fallback: Any = None) -> Callable[[Callable[..., T]], Callable[..., T]]:
        """Decorator form of the circuit breaker."""

        def decorator(func: Callable[..., T]) -> Callable[..., T]:
            @wraps(func)
            def wrapper(*args: Any, **kwargs: Any) -> T:
                current_state = self.state
                if current_state == self.OPEN:
                    logger.warning(
                        "Circuit breaker [%s] is OPEN. Call to %s skipped.",
                        self.name,
                        func.__name__,
                    )
                    return fallback() if callable(fallback) else fallback
                try:
                    result = func(*args, **kwargs)
                    self.record_success()
                    return result
                except Exception as exc:
                    self.record_failure()
                    logger.warning(
                        "Circuit breaker [%s] recorded error in %s: %s",
                        self.name,
                        func.__name__,
                        exc,
                    )
                    if fallback is not None:
                        return fallback() if callable(fallback) else fallback
                    raise

            return wrapper

        return decorator


# ============================================================================
# 3. Rate-Limiting Throttler & Debouncer
# ============================================================================

def throttle(min_interval: float) -> Callable[[Callable[..., T]], Callable[..., T | None]]:
    """HOF ensuring function is not executed more frequently than min_interval seconds."""

    def decorator(func: Callable[..., T]) -> Callable[..., T | None]:
        last_called = 0.0
        lock = threading.Lock()

        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T | None:
            nonlocal last_called
            now = time.monotonic()
            with lock:
                if now - last_called < min_interval:
                    return None
                last_called = now
            return func(*args, **kwargs)

        return wrapper

    return decorator


def debounce(wait_seconds: float) -> Callable[[Callable[..., Any]], Callable[..., None]]:
    """HOF debouncer that postpones function execution until wait_seconds has elapsed since last call."""

    def decorator(func: Callable[..., Any]) -> Callable[..., None]:
        timer: threading.Timer | None = None
        lock = threading.Lock()

        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> None:
            nonlocal timer
            with lock:
                if timer is not None:
                    timer.cancel()
                timer = threading.Timer(wait_seconds, func, args=args, kwargs=kwargs)
                timer.daemon = True
                timer.start()

        return wrapper

    return decorator


# ============================================================================
# 4. Thread-Safe LRU Cache with Time-To-Live (TTL)
# ============================================================================

class TTLCache:
    """Thread-safe Least Recently Used (LRU) Cache with Time-To-Live expiration."""

    def __init__(self, ttl: float = 2.0, maxsize: int = 128) -> None:
        self.ttl = ttl
        self.maxsize = maxsize
        self._cache: OrderedDict[Any, tuple[Any, float]] = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: Any, default: Any = None) -> Any:
        with self._lock:
            if key not in self._cache:
                return default
            val, timestamp = self._cache[key]
            if (time.monotonic() - timestamp) > self.ttl:
                del self._cache[key]
                return default
            self._cache.move_to_end(key)
            return val

    def set(self, key: Any, value: Any) -> None:
        with self._lock:
            if key in self._cache:
                self._cache.move_to_end(key)
            self._cache[key] = (value, time.monotonic())
            if len(self._cache) > self.maxsize:
                self._cache.popitem(last=False)

    def clear(self) -> None:
        with self._lock:
            self._cache.clear()

    def __call__(self, ttl: float | None = None) -> Callable[[Callable[..., T]], Callable[..., T]]:
        """Decorator usage: @cache(ttl=5.0)."""
        cache_ttl = ttl or self.ttl

        def decorator(func: Callable[..., T]) -> Callable[..., T]:
            @wraps(func)
            def wrapper(*args: Any, **kwargs: Any) -> T:
                # Key based on stringified args for simple hashability
                try:
                    key = (args, tuple(sorted(kwargs.items())))
                except TypeError:
                    key = str(args) + str(kwargs)
                cached = self.get(key)
                if cached is not None:
                    return cached
                res = func(*args, **kwargs)
                if res is not None:
                    self.set(key, res)
                return res

            return wrapper

        return decorator


# ============================================================================
# 5. Defensive Execution Wrappers
# ============================================================================

def safe_call(
    func: Callable[..., T],
    *args: Any,
    fallback: T | None = None,
    log_errors: bool = True,
    **kwargs: Any,
) -> T | None:
    """Execute any callable/lambda defensively; never raise an unhandled exception."""
    try:
        return func(*args, **kwargs)
    except Exception as exc:
        if log_errors:
            logger.debug("safe_call caught exception in %s: %s", getattr(func, "__name__", "callable"), exc)
        return fallback

