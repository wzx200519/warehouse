# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

import keyword
import tomllib

from dataclasses import dataclass
from pathlib import Path

import click

from warehouse.cli import warehouse

_LICENSE_HEADER = "# SPDX-License-Identifier: Apache-2.0\n"


@dataclass(frozen=True, slots=True)
class ScaffoldConfig:
    package_roots: tuple[str, ...]
    tests_root: Path
    python_version: str
    ruff_target_version: str


@dataclass(frozen=True, slots=True)
class ScaffoldResult:
    config: ScaffoldConfig
    module_path: Path
    test_path: Path
    created_paths: tuple[Path, ...]
    module_updated: bool
    test_updated: bool


@warehouse.group()
def scaffold() -> None:
    pass


@scaffold.command("python-module")
@click.argument("module_path")
@click.option(
    "--project-root",
    type=click.Path(exists=True, file_okay=False, path_type=Path),
    default=Path("."),
)
@click.option(
    "--pyproject",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    default=Path("pyproject.toml"),
)
@click.option("--overwrite", is_flag=True)
def python_module(
    module_path: str,
    project_root: Path,
    pyproject: Path,
    overwrite: bool,
) -> None:
    resolved_project_root = project_root.resolve()
    resolved_pyproject = pyproject.resolve()
    results = write_python_module_template(
        project_root=resolved_project_root,
        pyproject_path=resolved_pyproject,
        module_path=module_path,
        overwrite=overwrite,
    )

    for created_path in results.created_paths:
        relative_path = created_path.relative_to(resolved_project_root)
        click.echo(f"Created {relative_path}")

    if results.module_updated:
        relative_path = results.module_path.relative_to(resolved_project_root)
        click.echo(f"Updated {relative_path}")

    if results.test_updated:
        relative_path = results.test_path.relative_to(resolved_project_root)
        click.echo(f"Updated {relative_path}")

    click.echo(
        "Template matches Python "
        f"{results.config.python_version}, "
        f"Ruff {results.config.ruff_target_version}, "
        f"pytest root {results.config.tests_root.as_posix()}."
    )


def write_python_module_template(
    *,
    project_root: Path,
    pyproject_path: Path,
    module_path: str,
    overwrite: bool,
) -> ScaffoldResult:
    config = load_scaffold_config(pyproject_path)
    module_parts = validate_module_path(module_path, config.package_roots)

    module_file = project_root.joinpath(*module_parts[:-1], f"{module_parts[-1]}.py")
    test_file = project_root / build_test_path(config.tests_root, module_parts)

    if not overwrite:
        refuse_existing_file(module_file)
        refuse_existing_file(test_file)

    created_paths: list[Path] = []
    created_paths.extend(ensure_package_tree(project_root, module_parts[:-1]))
    created_paths.extend(
        ensure_package_tree(
            project_root,
            config.tests_root.parts + module_parts[1:-1],
        )
    )

    module_created = write_template_file(
        module_file,
        render_module_template(module_parts),
    )
    if module_created:
        created_paths.append(module_file)

    test_created = write_template_file(
        test_file,
        render_test_template(module_parts),
    )
    if test_created:
        created_paths.append(test_file)

    return ScaffoldResult(
        config=config,
        module_path=module_file,
        test_path=test_file,
        created_paths=tuple(created_paths),
        module_updated=not module_created,
        test_updated=not test_created,
    )


def load_scaffold_config(pyproject_path: Path) -> ScaffoldConfig:
    try:
        pyproject = tomllib.loads(pyproject_path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise click.ClickException(f"Missing pyproject.toml: {pyproject_path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise click.ClickException(f"Invalid pyproject.toml: {exc}") from exc

    try:
        tool_config = pyproject["tool"]
        coverage_run = tool_config["coverage"]["run"]
        pytest_config = tool_config["pytest"]
        mypy_config = tool_config["mypy"]
        ruff_config = tool_config["ruff"]
    except KeyError as exc:
        raise click.ClickException(
            f"pyproject.toml is missing [tool.{exc.args[0]}] settings"
        ) from exc

    package_roots = tuple(
        source
        for source in coverage_run.get("source", [])
        if source != "tests" and is_valid_identifier(source)
    )
    if not package_roots:
        raise click.ClickException(
            "[tool.coverage.run].source must include at least one importable "
            "package root"
        )

    tests_root = resolve_tests_root(
        pyproject_path.parent,
        pytest_config.get("testpaths", ["tests"]),
    )

    return ScaffoldConfig(
        package_roots=package_roots,
        tests_root=tests_root,
        python_version=str(mypy_config.get("python_version", "unknown")),
        ruff_target_version=str(ruff_config.get("target-version", "unknown")),
    )


def resolve_tests_root(project_root: Path, testpaths: list[str]) -> Path:
    configured_root = Path(testpaths[0]) if testpaths else Path("tests")
    unit_root = project_root / configured_root / "unit"
    if unit_root.exists():
        return configured_root / "unit"
    return configured_root


def validate_module_path(
    module_path: str,
    package_roots: tuple[str, ...],
) -> tuple[str, ...]:
    module_parts = tuple(module_path.split("."))
    if len(module_parts) < 2:
        raise click.ClickException(
            "module_path must be a dotted path such as warehouse.utils.example"
        )

    invalid_parts = [part for part in module_parts if not is_valid_identifier(part)]
    if invalid_parts:
        raise click.ClickException(
            "module_path contains invalid Python identifiers: "
            + ", ".join(invalid_parts)
        )

    if module_parts[0] not in package_roots:
        roots = ", ".join(package_roots)
        raise click.ClickException(
            "module_path must start with one of the coverage package roots: "
            f"{roots}"
        )

    return module_parts


def is_valid_identifier(value: str) -> bool:
    return value.isidentifier() and not keyword.iskeyword(value)


def build_test_path(
    tests_root: Path,
    module_parts: tuple[str, ...],
) -> Path:
    return tests_root.joinpath(*module_parts[1:-1], f"test_{module_parts[-1]}.py")


def ensure_package_tree(
    project_root: Path,
    package_parts: tuple[str, ...],
) -> list[Path]:
    current = project_root
    created_paths: list[Path] = []

    for part in package_parts:
        current = current / part
        current.mkdir(exist_ok=True)
        init_path = current / "__init__.py"
        if not init_path.exists():
            init_path.write_text(f"{_LICENSE_HEADER}\n", encoding="utf-8")
            created_paths.append(init_path)

    return created_paths


def refuse_existing_file(path: Path) -> None:
    if path.exists():
        raise click.ClickException(
            f"Refusing to overwrite existing file without --overwrite: {path}"
        )


def write_template_file(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    was_created = not path.exists()
    path.write_text(content, encoding="utf-8")
    return was_created


def render_module_template(module_parts: tuple[str, ...]) -> str:
    module_name = module_parts[-1]
    function_name = f"normalize_{module_name}"
    result_name = f"{pascal_case(module_name)}Result"

    return "\n".join(
        [
            _LICENSE_HEADER.rstrip(),
            "",
            "from __future__ import annotations",
            "",
            "from dataclasses import dataclass",
            "",
            "",
            "@dataclass(frozen=True, slots=True)",
            f"class {result_name}:",
            "    value: str",
            "",
            "",
            f"def {function_name}(value: str) -> {result_name}:",
            "    normalized_value = value.strip()",
            "    if not normalized_value:",
            '        raise ValueError("value must not be empty")',
            f"    return {result_name}(value=normalized_value)",
            "",
        ]
    )


def render_test_template(module_parts: tuple[str, ...]) -> str:
    module_name = module_parts[-1]
    import_path = ".".join(module_parts)
    function_name = f"normalize_{module_name}"
    result_name = f"{pascal_case(module_name)}Result"

    return "\n".join(
        [
            _LICENSE_HEADER.rstrip(),
            "",
            "import pytest",
            "",
            f"from {import_path} import {result_name}, {function_name}",
            "",
            "",
            f"def test_{function_name}_trims_surrounding_whitespace() -> None:",
            (
                f'    assert {function_name}("  example  ") '
                f'== {result_name}(value="example")'
            ),
            "",
            "",
            f"def test_{function_name}_rejects_blank_values() -> None:",
            '    with pytest.raises(ValueError, match="value must not be empty"):',
            f'        {function_name}("   ")',
            "",
        ]
    )


def pascal_case(value: str) -> str:
    return "".join(part[:1].upper() + part[1:] for part in value.split("_"))
