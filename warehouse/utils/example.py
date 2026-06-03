# SPDX-License-Identifier: Apache-2.0

from typing import Any, Self


class Example:
    """Example class demonstrating project coding style and best practices."""

    def __init__(self, name: str, value: int) -> None:
        self.name = name
        self.value = value

    def greet(self) -> str:
        """Return a greeting message from this example instance."""
        return f"Hello, {self.name}!"

    def double_value(self) -> int:
        """Return double the value of this example instance."""
        return self.value * 2

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Self:
        """Create an Example instance from a dictionary."""
        return cls(name=data["name"], value=data["value"])

    def __repr__(self) -> str:
        return f"Example(name={self.name!r}, value={self.value!r})"
