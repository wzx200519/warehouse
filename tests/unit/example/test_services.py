# SPDX-License-Identifier: Apache-2.0

import pretend
import pytest

from warehouse.example.interfaces import IExampleService
from warehouse.example.services import ExampleService


class TestExampleService:
    """Tests for ExampleService class."""

    def test_do_something_returns_true(self):
        """Test that do_something returns True for valid input."""
        service = ExampleService()
        assert service.do_something("test") is True

    def test_create_service(self):
        """Test that create_service returns a service instance."""
        request = pretend.stub(registry=pretend.stub(settings={}))
        service = ExampleService.create_service(None, request)
        assert isinstance(service, ExampleService)