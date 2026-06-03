#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

def create_module(module_path: str) -> None:
    src_path = Path(module_path)
    if src_path.suffix != ".py":
        src_path = src_path.with_suffix(".py")
        
    if not str(src_path).startswith("warehouse/"):
        print("错误：模块路径必须以 'warehouse/' 开头")
        sys.exit(1)
        
    # 解析路径结构
    parts = list(src_path.with_suffix("").parts)
    module_dot_path = ".".join(parts)
    module_name = parts[-1]
    
    # 自动映射测试路径 (例如 warehouse/utils/foo.py -> tests/unit/utils/test_foo.py)
    test_parts = ["tests", "unit"] + parts[1:-1] + [f"test_{module_name}.py"]
    test_path = Path(*test_parts)
    
    # 确保目录存在并自动生成 __init__.py (避免 Ruff INP001 报错)
    def ensure_init(directory: Path, root_name: str) -> None:
        directory.mkdir(parents=True, exist_ok=True)
        current = directory
        while current.name not in (root_name, ""):
            init_file = current / "__init__.py"
            if not init_file.exists():
                init_file.touch()
            current = current.parent

    ensure_init(src_path.parent, "warehouse")
    ensure_init(test_path.parent, "tests")
    
    # 1. 生成业务代码模板
    src_content = f'''\
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from typing import Any


def sample_{module_name}() -> str:
    """Sample function for {module_name}."""
    return "Hello from {module_name}!"
'''
    
    # 2. 生成测试代码模板
    test_content = f'''\
import pytest

from {module_dot_path} import sample_{module_name}


@pytest.mark.unit
def test_sample_{module_name}() -> None:
    result = sample_{module_name}()
    
    assert result == "Hello from {module_name}!"
'''

    # 写入文件
    for path, content in [(src_path, src_content), (test_path, test_content)]:
        if not path.exists():
            path.write_text(content)
            print(f"✅ 创建文件: {path}")
        else:
            print(f"⚠️ 文件已存在: {path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="自动生成符合规范的 Warehouse 模块与测试文件")
    parser.add_argument("module_path", help="模块路径，例如: warehouse/utils/helpers.py")
    args = parser.parse_args()
    create_module(args.module_path)
