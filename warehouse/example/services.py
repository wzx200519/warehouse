# SPDX-License-Identifier: Apache-2.0

"""Service implementations for example."""

from __future__ import annotations

import typing

from zope.interface import implementer

from warehouse.example.interfaces import IExampleService

if typing.TYPE_CHECKING:
    from pyramid.config import Configurator


@implementer(IExampleService)
class ExampleService:
    """Service implementation for example."""

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
        ExampleService.create_service, IExampleService
    )