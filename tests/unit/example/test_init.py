# SPDX-License-Identifier: Apache-2.0

import pretend

from warehouse.example import includeme
from warehouse.example.interfaces import IExampleService
from warehouse.example.services import ExampleService


def test_includeme():
    config = pretend.stub(
        register_service_factory=pretend.call_recorder(lambda *a, **k: None)
    )

    includeme(config)

    assert config.register_service_factory.calls == [
        pretend.call(ExampleService.create_service, IExampleService)
    ]