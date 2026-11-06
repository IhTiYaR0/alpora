"""Safe external command execution with timeout, circuit breaker and missing-binary handling."""
from __future__ import annotations

import shutil
import subprocess
from typing import Sequence

from ..core.resilience import CircuitBreaker


class SafeRunner:
    """Wrapper around subprocess.run with defensive failure modes and circuit breaking."""

    _breakers: dict[str, CircuitBreaker] = {}

    @classmethod
    def get_circuit_breaker(cls, binary: str) -> CircuitBreaker:
        if binary not in cls._breakers:
            cls._breakers[binary] = CircuitBreaker(
                name=f"daemon:{binary}",
                failure_threshold=4,
                recovery_timeout=10.0,
            )
        return cls._breakers[binary]

    @staticmethod
    def which(binary: str) -> str | None:
        return shutil.which(binary)

    @classmethod
    def is_available(cls, binary: str) -> bool:
        return cls.which(binary) is not None

    @classmethod
    def run(
        cls,
        cmd: Sequence[str],
        timeout: float = 5.0,
        check: bool = False,
        default_output: str = "",
        use_circuit_breaker: bool = True,
        timeout_sec: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        """Execute a command safely with Circuit Breaker protection. Never raises FileNotFoundError or TimeoutExpired."""
        if timeout_sec is not None:
            timeout = timeout_sec
        if not cmd:
            return subprocess.CompletedProcess(list(cmd), returncode=1, stdout="", stderr="Empty command")

        binary = cmd[0]
        if not cls.which(binary):
            res = subprocess.CompletedProcess(
                list(cmd),
                returncode=127,
                stdout=default_output,
                stderr=f"{binary}: command not found",
            )
            if check:
                raise subprocess.CalledProcessError(127, list(cmd), output=default_output, stderr=res.stderr)
            return res

        breaker = cls.get_circuit_breaker(binary) if use_circuit_breaker else None
        if breaker and breaker.state == CircuitBreaker.OPEN:
            # Circuit is open - fail fast without hanging the process
            res = subprocess.CompletedProcess(
                list(cmd),
                returncode=125,
                stdout=default_output,
                stderr=f"Circuit breaker for {binary} is OPEN; call isolated.",
            )
            if check:
                raise subprocess.CalledProcessError(125, list(cmd), output=default_output, stderr=res.stderr)
            return res

        try:
            res = subprocess.run(
                list(cmd),
                capture_output=True,
                text=True,
                timeout=timeout,
                check=check,
            )
            if breaker:
                if res.returncode == 0:
                    breaker.record_success()
                else:
                    breaker.record_failure()
            return res
        except subprocess.TimeoutExpired as exc:
            if breaker:
                breaker.record_failure()
            res = subprocess.CompletedProcess(
                list(cmd),
                returncode=124,
                stdout=default_output,
                stderr=f"Command timed out after {timeout}s: {exc}",
            )
            if check:
                raise
            return res
        except (subprocess.SubprocessError, OSError) as exc:
            if breaker:
                breaker.record_failure()
            res = subprocess.CompletedProcess(
                list(cmd),
                returncode=1,
                stdout=default_output,
                stderr=str(exc),
            )
            if check:
                raise
            return res
