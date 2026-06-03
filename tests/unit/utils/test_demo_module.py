# SPDX-License-Identifier: Apache-2.0

import pytest

from warehouse.utils.demo_module import DemoModule


class TestDemoModule:
    def test_init(self):
        obj = DemoModule(name="Test", value=42)
        assert obj.name == "Test"
        assert obj.value == 42

    def test_get_info(self):
        obj = DemoModule(name="Test", value=42)
        assert obj.get_info() == "Test: 42"

    def test_from_dict(self):
        data = {"name": "Test", "value": 42}
        obj = DemoModule.from_dict(data)
        assert obj.name == "Test"
        assert obj.value == 42

    def test_repr(self):
        obj = DemoModule(name="Test", value=42)
        assert repr(obj) == "DemoModule(name='Test', value=42)"

    @pytest.mark.parametrize(
        "name, value, expected",
        [
            ("Zero", 0, "Zero: 0"),
            ("Positive", 100, "Positive: 100"),
            ("Negative", -5, "Negative: -5"),
        ],
    )
    def test_get_info_parametrized(self, name, value, expected):
        obj = DemoModule(name=name, value=value)
        assert obj.get_info() == expected
