# 并行测试问题定位与修复指南

## 问题概述

在启用 `--numprocesses=auto`、`--disable-socket` 和严格警告处理 (`filterwarnings = ["error", ...]`) 的 pytest 配置下，测试可能会在并行执行时偶发失败，且失败可能只在特定 worker 上出现。

## 常见问题类型及定位方法

### 1. 全局状态污染（最常见）

**表现**：测试在并行执行时出现随机失败，但在单独执行时通过

**定位方法**：
```bash
# 禁用 xdist 并行，使用单进程执行看是否还能复现
pytest -v tests/ --numprocesses=0

# 或者按顺序执行特定的测试文件
pytest -v tests/unit/test_a.py tests/unit/test_b.py
```

**检查点**：
- 查找直接修改模块级全局变量的代码（如 `stripe.api_key`）
- 查找 `os.environ`、`sys.path` 等系统级状态修改
- 检查 fixture 中的全局副作用

**修复方案**：
```python
# 不要这样做：
@pytest.fixture
def bad_fixture():
    module.global_var = "test_value"
    return something

# 应该这样做：
@pytest.fixture
def good_fixture():
    original = module.global_var
    module.global_var = "test_value"
    yield something
    module.global_var = original  # 恢复原状
```

### 2. 未被忽略的警告导致失败

**表现**：错误信息是 `DeprecationWarning` 或其他警告被当作错误

**定位方法**：
```bash
# 运行单个测试文件，查看完整的警告输出
pytest -v tests/unit/test_flaky.py --disable-warning=error

# 或者临时禁用所有警告处理，查看哪些警告被触发
pytest -v tests/ --tb=long
```

**修复方案**：在 `pyproject.toml` 的 `filterwarnings` 中添加对应的忽略规则

### 3. 资源竞争

**表现**：数据库、文件系统或网络相关测试失败

**定位方法**：
- 检查 `worker_id` 的使用
- 查看是否有共享资源未隔离

## 调试技巧

### 1. 针对特定 worker 调试
```bash
# 使用特定的 worker id 运行测试
pytest -v tests/unit/test_issue.py -n 1 --dist=loadscope

# 或者完全禁用 xdist
pytest -v tests/unit/test_issue.py
```

### 2. 捕获警告
创建临时的 conftest.py：
```python
import warnings
def pytest_configure(config):
    warnings.simplefilter("always")
```

### 3. 调试输出
```bash
# 启用详细输出和错误回溯
pytest -vvs tests/ --tb=long --numprocesses=2
```

## 已修复的问题

1. **stripe 全局状态污染** - 在 `tests/conftest.py` 中的 `billing_service` fixture，现在正确地保存和恢复 stripe 的原始配置
2. **警告处理** - 在 `pyproject.toml` 中添加了更多的警告忽略规则，防止常见警告导致测试失败
3. **xdist 配置优化** - 添加了测试分组配置，减少依赖冲突

## 最佳实践

1. **Fixture 隔离**：每个 fixture 都应该使用 `yield` 并在 teardown 阶段清理/恢复状态
2. **避免全局状态**：尽量避免在测试中修改全局变量
3. **使用 worker_id**：对于需要隔离的资源，利用 `worker_id` 参数
4. **明确忽略警告**：只在确定安全的情况下忽略警告，并添加注释说明原因
5. **定期检查**：定期运行测试并查看是否有新的警告需要处理
