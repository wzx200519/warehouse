# SPDX-License-Identifier: Apache-2.0

import pytest

from warehouse.utils.example import Example


class TestExample:
    def test_init(self):
        example = Example(name="Test", value=42)
        assert example.name == "Test"
        assert example.value == 42

    def test_greet(self):
        example = Example(name="Alice", value=10)
        assert example.greet() == "Hello, Alice!"

    def test_double_value(self):
        example = Example(name="Test", value=5)
        assert example.double_value() == 10

    def test_from_dict(self):
        data = {"name": "Bob", "value": 20}
        example = Example.from_dict(data)
        assert example.name == "Bob"
        assert example.value == 20

    def test_repr(self):
        example = Example(name="Test", value=42)
        assert repr(example) == "Example(name='Test', value=42)"

    @pytest.mark.parametrize(
        "value, expected",
        [
            (0, 0),
            (1, 2),
            (-3, -6),
            (100, 200),
        ],
    )
    def test_double_value_parametrized(self, value, expected):
        example = Example(name="Test", value=value)
        assert example.double_value() == expected
