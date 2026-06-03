#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

import argparse
import os
import sys
from pathlib import Path


def create_module_structure(module_path: str, base_dir: Path = Path.cwd()) -> None:
    """
    Create a new module structure with the given path.
    
    :param module_path: Module path, e.g., 'utils.new_module' or 'new_module'
    :param base_dir: Base directory of the project
    """
    # Split module path into parts
    module_parts = module_path.split('.')
    
    # Create source file in warehouse/ directory
    source_dir = base_dir / 'warehouse'
    for part in module_parts[:-1]:
        source_dir = source_dir / part
        if not source_dir.exists():
            source_dir.mkdir(parents=True)
            # Create __init__.py if it doesn't exist
            init_file = source_dir / '__init__.py'
            if not init_file.exists():
                init_file.touch()
    
    module_name = module_parts[-1]
    source_file = source_dir / f'{module_name}.py'
    
    # Create source file content
    source_content = '''# SPDX-License-Identifier: Apache-2.0

from typing import Any, Self


class {class_name}:
    """{class_name} class for {module_name} module."""

    def __init__(self, name: str, value: int) -> None:
        self.name = name
        self.value = value

    def get_info(self) -> str:
        """Return information about this {class_name} instance."""
        return f"{self.name}: {self.value}"

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Self:
        """Create a {class_name} instance from a dictionary."""
        return cls(name=data["name"], value=data["value"])

    def __repr__(self) -> str:
        return f"{class_name}(name={{self.name!r}}, value={{self.value!r}})"
'''.format(
        class_name=module_name.capitalize(),
        module_name=module_name
    )
    
    source_file.write_text(source_content)
    print(f"Created: {source_file}")
    
    # Create test file in tests/unit/ directory
    test_dir = base_dir / 'tests' / 'unit'
    for part in module_parts[:-1]:
        test_dir = test_dir / part
        if not test_dir.exists():
            test_dir.mkdir(parents=True)
            # Create __init__.py if it doesn't exist
            init_file = test_dir / '__init__.py'
            if not init_file.exists():
                init_file.touch()
    
    test_file = test_dir / f'test_{module_name}.py'
    
    # Create test file content
    test_content = '''# SPDX-License-Identifier: Apache-2.0

import pytest

from warehouse.{module_path} import {class_name}


class Test{class_name}:
    def test_init(self):
        obj = {class_name}(name="Test", value=42)
        assert obj.name == "Test"
        assert obj.value == 42

    def test_get_info(self):
        obj = {class_name}(name="Test", value=42)
        assert obj.get_info() == "Test: 42"

    def test_from_dict(self):
        data = {{"name": "Test", "value": 42}}
        obj = {class_name}.from_dict(data)
        assert obj.name == "Test"
        assert obj.value == 42

    def test_repr(self):
        obj = {class_name}(name="Test", value=42)
        assert repr(obj) == "{class_name}(name='Test', value=42)"

    @pytest.mark.parametrize(
        "name, value, expected",
        [
            ("Zero", 0, "Zero: 0"),
            ("Positive", 100, "Positive: 100"),
            ("Negative", -5, "Negative: -5"),
        ],
    )
    def test_get_info_parametrized(self, name, value, expected):
        obj = {class_name}(name=name, value=value)
        assert obj.get_info() == expected
'''.format(
        module_path=module_path,
        class_name=module_name.capitalize()
    )
    
    test_file.write_text(test_content)
    print(f"Created: {test_file}")
    
    # Add import to __init__.py if needed
    init_file = source_dir / '__init__.py'
    print(f"\nNext steps:")
    print(f"1. Edit {source_file} to implement your functionality")
    print(f"2. Edit {test_file} to add comprehensive tests")
    print(f"3. Consider adding imports to {init_file} if needed")
    print(f"4. Run checks:")
    print(f"   - ruff check {source_file} {test_file}")
    print(f"   - mypy {source_file}")
    print(f"   - pytest {test_file}")
    print(f"   - coverage run -m pytest {test_file} && coverage report -m")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a new Python module with project-standard structure and tests."
    )
    parser.add_argument(
        "module",
        help="Module path, e.g., 'utils.new_module' or 'new_module'",
    )
    
    args = parser.parse_args()
    
    try:
        create_module_structure(args.module)
        return 0
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
