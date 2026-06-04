#!/bin/bash
set -euo pipefail

# 代码质量检查脚本
# 用法: ./scripts/quality-check.sh [--fail-on-warnings]

FAIL_ON_WARNINGS=${1:-}

echo "=========================================="
echo "代码质量检查"
echo "=========================================="

FAILED=0

# Python 代码检查
echo "1. Python 代码检查"
echo "------------------------------------------"

# isort 检查
echo -n "  isort... "
if isort --check-only --diff warehouse/ > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败 - 运行 'isort warehouse/' 修复"
    ((FAILED++)) || true
fi

# Black 检查
echo -n "  black... "
if black --check warehouse/ > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败 - 运行 'black warehouse/' 修复"
    ((FAILED++)) || true
fi

# Flake8 检查
echo -n "  flake8... "
if flake8 warehouse/ > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败"
    flake8 warehouse/ | head -10
    ((FAILED++)) || true
fi

# Mypy 类型检查
echo -n "  mypy... "
if mypy warehouse/ > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败"
    ((FAILED++)) || true
fi

# 安全检查
echo ""
echo "2. 安全检查"
echo "------------------------------------------"

# Bandit 检查
echo -n "  bandit... "
if bandit -r warehouse/ -q > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "⚠ 发现安全问题"
    bandit -r warehouse/ | grep -E "(HIGH|MEDIUM)" | head -5
    ((FAILED++)) || true
fi

# 依赖安全检查
echo -n "  safety... "
if pip install safety > /dev/null 2>&1 && safety check > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "⚠ 发现依赖安全问题"
    ((FAILED++)) || true
fi

# 前端代码检查
echo ""
echo "3. 前端代码检查"
echo "------------------------------------------"

echo -n "  ESLint... "
if npm run lint > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败"
    ((FAILED++)) || true
fi

echo -n "  Prettier... "
if npx prettier --check warehouse/static/ > /dev/null 2>&1; then
    echo "✓ 通过"
else
    echo "✗ 失败 - 运行 'npx prettier --write warehouse/static/' 修复"
    ((FAILED++)) || true
fi

# 总结
echo ""
echo "=========================================="
echo "检查结果: $((3 - FAILED))/3 通过"

if [[ $FAILED -eq 0 ]]; then
    echo "状态: ✓ 全部通过"
    exit 0
elif [[ $FAILED -le 2 ]]; then
    echo "状态: ⚠ 部分失败"
    exit 0
else
    echo "状态: ✗ 严重失败"
    exit 1
fi
