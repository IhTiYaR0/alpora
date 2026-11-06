"""Base DTO, Event Envelope and Serialization for ALPORA IPC."""
from dataclasses import asdict, dataclass, field
import json
import time
from typing import Any, Dict, Optional


@dataclass
class BaseDTO:
    """Base class for all Data Transfer Objects with validation and serialization."""

    def to_dict(self) -> Dict[str, Any]:
        """Convert DTO to native python dict."""
        return asdict(self)

    def to_json(self) -> str:
        """Convert DTO to clean JSON string."""
        return json.dumps(self.to_dict(), ensure_ascii=False)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]):
        """Instantiate DTO from dictionary, ignoring extraneous fields for forward compatibility."""
        if not isinstance(data, dict):
            raise ValueError(f"Expected dict for {cls.__name__}, got {type(data).__name__}")
        valid_fields = cls.__dataclass_fields__.keys()
        filtered = {k: v for k, v in data.items() if k in valid_fields}
        return cls(**filtered)


@dataclass
class ResponseDTO(BaseDTO):
    """Standardized response structure for IPC calls."""

    success: bool
    data: Any = field(default_factory=dict)
    error: Optional[str] = None
    code: int = 0
    id: Optional[str] = None


@dataclass
class ShellEventEnvelope(BaseDTO):
    """Standardized event packet broadcast over socket / IPC stream."""

    domain: str
    event: str
    data: Dict[str, Any] = field(default_factory=dict)
    version: str = "1.0"
    timestamp: float = field(default_factory=time.time)

