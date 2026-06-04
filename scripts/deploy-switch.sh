#!/bin/bash
set -euo pipefail

# 蓝绿部署切换脚本
# 用法: ./scripts/deploy-switch.sh --target production

TARGET=""
GREEN_DEPLOYMENT="warehouse-green"
BLUE_DEPLOYMENT="warehouse-blue"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "缺少 --target 参数"
    exit 1
fi

echo "执行蓝绿切换到 $TARGET..."

# 获取当前活跃的部署
ACTIVE=$(kubectl get service "warehouse-$TARGET" -o jsonpath='{.spec.selector.active}')

if [[ "$ACTIVE" == "blue" ]]; then
    NEW_ACTIVE="green"
    NEW_DEPLOYMENT="$GREEN_DEPLOYMENT"
else
    NEW_ACTIVE="blue"
    NEW_DEPLOYMENT="$BLUE_DEPLOYMENT"
fi

echo "切换到: $NEW_ACTIVE ($NEW_DEPLOYMENT)"

# 等待新部署就绪
kubectl rollout status deployment/"$NEW_DEPLOYMENT" -n "warehouse-$TARGET" --timeout=300s

# 切换流量
kubectl patch service "warehouse-$TARGET" \
    -p "{\"spec\":{\"selector\":{\"active\":\"$NEW_ACTIVE\"}}}" \
    -n "warehouse-$TARGET"

echo "蓝绿切换完成！"

# 清理旧部署（可选）
echo "准备清理旧部署..."
# 保留旧部署用于快速回滚
