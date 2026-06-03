# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

from pathlib import Path

import warehouse.cli.scaffold


def test_load_scaffold_config_prefers_unit_test_root(tmp_path: Path) -> None:
    (tmp_path / "tests" / "unit").mkdir(parents=True)
    pyproject_path = tmp_path / "pyproject.toml"
    pyproject_path.write_text(
        "\n".join(
            [
                "[tool.coverage.run]",
                'source = ["warehouse", "tests"]',
                "",
                "[tool.pytest]",
                'testpaths = ["tests/"]',
                "",
                "[tool.mypy]",
                'python_version = "3.14"',
                "",
                "[tool.ruff]",
                'target-version = "py314"',
                "",
            ]
        ),
        encoding="utf-8",
    )

    config = warehouse.cli.scaffold.load_scaffold_config(pyproject_path)

    assert config.package_roots == ("warehouse",)
    assert config.tests_root == Path("tests/unit")
    assert config.python_version == "3.14"
    assert config.ruff_target_version == "py314"


def test_python_module_command_generates_project_scaffold(cli) -> None:
    Path("pyproject.toml").write_text(
        "\n".join(
            [
                "[tool.coverage.run]",
                'source = ["warehouse", "tests"]',
                "",
                "[tool.pytest]",
                'testpaths = ["tests/"]',
                "",
                "[tool.mypy]",
                'python_version = "3.14"',
                "",
                "[tool.ruff]",
                'target-version = "py314"',
                "",
            ]
        ),
        encoding="utf-8",
    )
    Path("tests/unit").mkdir(parents=True)

    result = cli.invoke(
        warehouse.cli.scaffold.scaffold,
        ["python-module", "warehouse.utils.example"],
    )

    assert result.exit_code == 0
    assert Path("warehouse/__init__.py").read_text(encoding="utf-8") == (
        "# SPDX-License-Identifier: Apache-2.0\n\n"
    )
    assert Path("warehouse/utils/__init__.py").read_text(encoding="utf-8") == (
        "# SPDX-License-Identifier: Apache-2.0\n\n"
    )
    assert Path("tests/__init__.py").read_text(encoding="utf-8") == (
        "# SPDX-License-Identifier: Apache-2.0\n\n"
    )
    assert Path("tests/unit/__init__.py").read_text(encoding="utf-8") == (
        "# SPDX-License-Identifier: Apache-2.0\n\n"
    )
    assert Path("tests/unit/utils/__init__.py").read_text(encoding="utf-8") == (
        "# SPDX-License-Identifier: Apache-2.0\n\n"
    )
    assert Path("warehouse/utils/example.py").read_text(encoding="utf-8") == (
        warehouse.cli.scaffold.render_module_template(("warehouse", "utils", "example"))
    )
    assert Path("tests/unit/utils/test_example.py").read_text(encoding="utf-8") == (
        warehouse.cli.scaffold.render_test_template(("warehouse", "utils", "example"))
    )
    assert "Template matches Python 3.14, Ruff py314, pytest root tests/unit." in (
        result.output
    )


def test_python_module_command_rejects_existing_files_without_overwrite(cli) -> None:
    Path("pyproject.toml").write_text(
        "\n".join(
            [
                "[tool.coverage.run]",
                'source = ["warehouse", "tests"]',
                "",
                "[tool.pytest]",
                'testpaths = ["tests/"]',
                "",
                "[tool.mypy]",
                'python_version = "3.14"',
                "",
                "[tool.ruff]",
                'target-version = "py314"',
                "",
            ]
        ),
        encoding="utf-8",
    )
    Path("tests/unit").mkdir(parents=True)
    Path("warehouse/utils").mkdir(parents=True)
    Path("warehouse/utils/example.py").write_text("existing\n", encoding="utf-8")

    result = cli.invoke(
        warehouse.cli.scaffold.scaffold,
        ["python-module", "warehouse.utils.example"],
    )

    assert result.exit_code == 1
    assert "Refusing to overwrite existing file without --overwrite" in result.output
