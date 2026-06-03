# SPDX-License-Identifier: Apache-2.0

"""Interface definitions for example."""

from __future__ import annotations

from zope.interface import Interface


class IExampleService(Interface):
    """Interface for example service implementations."""

    def do_something(value: str) -> bool:
        """Perform an operation.

        Args:
            value: The input value to process.

        Returns:
            True if successful, False otherwise.
        """