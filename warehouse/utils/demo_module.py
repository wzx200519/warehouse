# SPDX-License-Identifier: Apache-2.0

from typing import Any, Self


class DemoModule:
    """DemoModule class for demo_module module."""

    def __init__(self, name: str, value: int) -> None:
        self.name = name
        self.value = value

    def get_info(self) -> str:
        """Return information about this DemoModule instance."""
        return f"{self.name}: {self.value}"

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Self:
        """Create a DemoModule instance from a dictionary."""
        return cls(name=data["name"], value=data["value"])

    def __repr__(self) -> str:
        return f"DemoModule(name={self.name!r}, value={self.value!r})"
