# SPDX-License-Identifier: Apache-2.0

"""Package for example."""

from warehouse.example.interfaces import IExampleService
from warehouse.example.services import ExampleService


__all__ = ["IExampleService", "ExampleService", "includeme"]