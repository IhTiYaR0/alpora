"""Unit tests for fault-tolerance, HOF decorators, and defensive algorithms in poly_shell.resilience."""
import time
import unittest

from poly_shell.resilience import (
    CircuitBreaker,
    TTLCache,
    debounce,
    retry,
    safe_call,
    throttle,
)


class TestResiliencePatterns(unittest.TestCase):
    def test_retry_success_after_failure(self):
        attempts = 0

        @retry(max_attempts=3, backoff_factor=1.1, initial_delay=0.01)
        def flaky():
            nonlocal attempts
            attempts += 1
            if attempts < 2:
                raise ValueError("Transient error")
            return "recovered"

        result = flaky()
        self.assertEqual(result, "recovered")
        self.assertEqual(attempts, 2)

    def test_retry_fallback_when_exhausted(self):
        @retry(max_attempts=2, initial_delay=0.01, fallback="safe_default")
        def always_fails():
            raise RuntimeError("Fatal hardware failure")

        self.assertEqual(always_fails(), "safe_default")

    def test_circuit_breaker_state_machine(self):
        cb = CircuitBreaker("test-service", failure_threshold=2, recovery_timeout=0.05)

        @cb(fallback="isolated")
        def unstable_operation(succeed: bool):
            if not succeed:
                raise ConnectionError("Service unreachable")
            return "success"

        # 1. Initially CLOSED
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertEqual(unstable_operation(True), "success")

        # 2. Trigger failures -> trip to OPEN
        unstable_operation(False)
        self.assertEqual(unstable_operation(False), "isolated")
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        # 3. Call fast-fails while OPEN
        self.assertEqual(unstable_operation(True), "isolated")

        # 4. Wait for recovery timeout -> HALF-OPEN
        time.sleep(0.06)
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        # 5. Success resets breaker back to CLOSED
        unstable_operation(True)
        unstable_operation(True)
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)

    def test_throttle_rate_limiting(self):
        call_count = 0

        @throttle(min_interval=0.08)
        def rate_limited():
            nonlocal call_count
            call_count += 1
            return call_count

        first = rate_limited()
        second = rate_limited()  # Throttled -> returns None
        time.sleep(0.09)
        third = rate_limited()  # Allowed

        self.assertEqual(first, 1)
        self.assertIsNone(second)
        self.assertEqual(third, 2)
        self.assertEqual(call_count, 2)

    def test_ttl_cache_expiration(self):
        cache = TTLCache(ttl=0.05, maxsize=2)
        cache.set("key1", "val1")
        self.assertEqual(cache.get("key1"), "val1")

        # Wait for expiration
        time.sleep(0.06)
        self.assertIsNone(cache.get("key1"))

    def test_ttl_cache_lru_eviction(self):
        cache = TTLCache(ttl=1.0, maxsize=2)
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)  # Evicts "a"

        self.assertIsNone(cache.get("a"))
        self.assertEqual(cache.get("b"), 2)
        self.assertEqual(cache.get("c"), 3)

    def test_safe_call_lambda_guard(self):
        # Lambda division by zero caught safely
        res = safe_call(lambda x, y: x / y, 10, 0, fallback=0.0)
        self.assertEqual(res, 0.0)

        # Normal execution
        res_ok = safe_call(lambda x, y: x + y, 5, 7, fallback=0)
        self.assertEqual(res_ok, 12)


if __name__ == "__main__":
    unittest.main()

