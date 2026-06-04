#!/bin/bash
set -euo pipefail

# 冒烟测试脚本
# 用法: ./scripts/smoke-tests.sh --environment staging [--strict]

ENVIRONMENT="staging"
STRICT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --strict)
            STRICT=true
            shift
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 根据环境设置 URL
case $ENVIRONMENT in
    staging)
        BASE_URL="https://staging.pypi.org"
        API_URL="https://staging.pypi.org/simple"
        ;;
    production)
        BASE_URL="https://pypi.org"
        API_URL="https://pypi.org/simple"
        ;;
    *)
        echo "未知环境: $ENVIRONMENT"
        exit 1
        ;;
esac

echo "=========================================="
echo "冒烟测试 - $ENVIRONMENT"
echo "=========================================="

FAILED=0

# 测试1: 健康检查端点
test_health() {
    echo -n "测试健康检查端点... "
    if curl -sf "$BASE_URL/health" > /dev/null; then
        echo "✓ 通过"
        return 0
    else
        echo "✗ 失败"
        return 1
    fi
}

# 测试2: 主页可访问
test_homepage() {
    echo -n "测试主页... "
    if curl -sf "$BASE_URL" | grep -q "<title>"; then
        echo "✓ 通过"
        return 0
    else
        echo "✗ 失败"
        return 1
    fi
}

# 测试3: 简单 API 可访问
test_simple_api() {
    echo -n "测试 Simple API... "
    RESPONSE=$(curl -sf -o /dev/null -w "%{http_code}" "$API_URL/")
    if [[ "$RESPONSE" == "200" ]]; then
        echo "✓ 通过"
        return 0
    else
        echo "✗ 失败 (HTTP $RESPONSE)"
        return 1
    fi
}

# 测试4: 包搜索功能
test_package_search() {
    echo -n "测试包搜索... "
    RESPONSE=$(curl -sf -o /dev/null -w "%{http_code}" "$BASE_URL/search/?q=pip")
    if [[ "$RESPONSE" == "200" ]]; then
        echo "✓ 通过"
        return 0
    else
        echo "✗ 失败 (HTTP $RESPONSE)"
        return 1
    fi
}

# 测试5: 响应时间
test_response_time() {
    echo -n "测试响应时间... "
    TIME=$(curl -sf -o /dev/null -w "%{time_total}" "$BASE_URL")
    
    if [[ "$STRICT" == true ]]; then
        THRESHOLD=2.0
    else
        THRESHOLD=5.0
    fi
    
    if (( $(echo "$TIME < $THRESHOLD" | bc -l) )); then
        echo "✓ 通过 (${TIME}s < ${THRESHOLD}s)"
        return 0
    else
        echo "✗ 失败 (${TIME}s >= ${THRESHOLD}s)"
        return 1
    fi
}

# 测试6: HTTPS 证书
test_ssl() {
    echo -n "测试 SSL 证书... "
    EXPIRY=$(echo | openssl s_client -servername "${BASE_URL#https://}" -connect "${BASE_URL#https://}":443 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [[ -n "$EXPIRY" ]]; then
        echo "✓ 通过 (证书有效至: $EXPIRY)"
        return 0
    else
        echo "✗ 失败"
        return 1
    fi
}

# 执行所有测试
test_health || ((FAILED++))
test_homepage || ((FAILED++))
test_simple_api || ((FAILED++))
test_package_search || ((FAILED++))
test_response_time || ((FAILED++))
test_ssl || ((FAILED++))

echo "=========================================="
echo "测试结果: $((6 - FAILED))/6 通过"

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
