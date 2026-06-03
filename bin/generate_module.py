# SPDX-License-Identifier: Apache-2.0

"""
Script to generate a new warehouse module with proper structure.

Usage:
    python -m bin.generate_module <module_name>
"""

from __future__ import annotations

import sys
from pathlib import Path


MODULE_TEMPLATE_INIT = '''\
# SPDX-License-Identifier: Apache-2.0

"""Package for {module_name}."""

from warehouse.{module_name}.interfaces import I{module_name_cap}Service
from warehouse.{module_name}.services import {module_name_cap}Service


__all__ = ["I{module_name_cap}Service", "{module_name_cap}Service", "includeme"]
'''

MODULE_TEMPLATE_SERVICES = '''\
# SPDX-License-Identifier: Apache-2.0

"""Service implementations for {module_name}."""

from __future__ import annotations

import typing

from zope.interface import implementer

from warehouse.{module_name}.interfaces import I{module_name_cap}Service

if typing.TYPE_CHECKING:
    from pyramid.config import Configurator


@implementer(I{module_name_cap}Service)
class {module_name_cap}Service:
    """Service implementation for {module_name}."""

    def __init__(self):
        pass

    @classmethod
    def create_service(cls, _context, request):
        return cls()

    def do_something(self, value: str) -> bool:
        """Perform an operation.

        Args:
            value: The input value to process.

        Returns:
            True if successful, False otherwise.
        """
        return True


def includeme(config: Configurator) -> None:
    """Include this module's services.

    Args:
        config: The Pyramid configurator.
    """
    config.register_service_factory(
        {module_name_cap}Service.create_service, I{module_name_cap}Service
    )
'''

MODULE_TEMPLATE_INTERFACES = '''\
# SPDX-License-Identifier: Apache-2.0

"""Interface definitions for {module_name}."""

from __future__ import annotations

from zope.interface import Interface


class I{module_name_cap}Service(Interface):
    """Interface for {module_name} service implementations."""

    def do_something(value: str) -> bool:
        """Perform an operation.

        Args:
            value: The input value to process.

        Returns:
            True if successful, False otherwise.
        """
'''

MODULE_TEMPLATE_MAIN = '''\
# SPDX-License-Identifier: Apache-2.0

"""CLI entry point for {module_name}."""


def main() -> int:
    """Run the {module_name} CLI."""
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'''

MODULE_TEMPLATE_TEST_INIT = '''\
# SPDX-License-Identifier: Apache-2.0

import pretend

from warehouse.{module_name} import includeme
from warehouse.{module_name}.interfaces import I{module_name_cap}Service
from warehouse.{module_name}.services import {module_name_cap}Service


def test_includeme():
    config = pretend.stub(
        register_service_factory=pretend.call_recorder(lambda *a, **k: None)
    )

    includeme(config)

    assert config.register_service_factory.calls == [
        pretend.call({module_name_cap}Service.create_service, I{module_name_cap}Service)
    ]
'''

MODULE_TEMPLATE_TEST_SERVICES = '''\
# SPDX-License-Identifier: Apache-2.0

import pretend
import pytest

from warehouse.{module_name}.interfaces import I{module_name_cap}Service
from warehouse.{module_name}.services import {module_name_cap}Service


class Test{module_name_cap}Service:
    """Tests for {module_name_cap}Service class."""

    def test_do_something_returns_true(self):
        """Test that do_something returns True for valid input."""
        service = {module_name_cap}Service()
        assert service.do_something("test") is True

    def test_create_service(self):
        """Test that create_service returns a service instance."""
        request = pretend.stub(registry=pretend.stub(settings={}))
        service = {module_name_cap}Service.create_service(None, request)
        assert isinstance(service, {module_name_cap}Service)
'''


def create_module(module_name: str) -> None:
    """Create a new warehouse module with proper structure.

    Args:
        module_name: The name of the module to create.
    """
    if not module_name.isidentifier():
        print(f"Error: '{module_name}' is not a valid Python module name.")
        sys.exit(1)

    module_name_lower = module_name.lower()
    module_name_cap = module_name.capitalize()

    warehouse_path = Path("warehouse") / module_name_lower
    tests_path = Path("tests/unit") / module_name_lower

    warehouse_path.mkdir(parents=True, exist_ok=True)
    tests_path.mkdir(parents=True, exist_ok=True)

    files = {
        warehouse_path / "__init__.py": MODULE_TEMPLATE_INIT.format(
            module_name=module_name_lower,
            module_name_cap=module_name_cap,
        ),
        warehouse_path / "interfaces.py": MODULE_TEMPLATE_INTERFACES.format(
            module_name=module_name_lower,
            module_name_cap=module_name_cap,
        ),
        warehouse_path / "services.py": MODULE_TEMPLATE_SERVICES.format(
            module_name=module_name_lower,
            module_name_cap=module_name_cap,
        ),
        warehouse_path / "__main__.py": MODULE_TEMPLATE_MAIN.format(
            module_name=module_name_lower,
        ),
        tests_path / "test_init.py": MODULE_TEMPLATE_TEST_INIT.format(
            module_name=module_name_lower,
            module_name_cap=module_name_cap,
        ),
        tests_path / "test_services.py": MODULE_TEMPLATE_TEST_SERVICES.format(
            module_name=module_name_lower,
            module_name_cap=module_name_cap,
        ),
    }

    for file_path, content in files.items():
        file_path.write_text(content)
        print(f"Created: {file_path}")

    print(f"\nModule '{module_name_lower}' created successfully!")
    print("\nTo verify the module, run:")
    print(f"  ruff check warehouse/{module_name_lower}/")
    print(f"  mypy warehouse/{module_name_lower}/")
    print(f"  pytest tests/unit/{module_name_lower}/ -m unit")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python -m bin.generate_module <module_name>")
        sys.exit(1)

    create_module(sys.argv[1])
