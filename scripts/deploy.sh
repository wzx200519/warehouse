#!/bin/bash
set -euo pipefail

# 部署脚本
# 用法: ./scripts/deploy.sh --environment staging --image <image> [--sbom <sbom>] [--rollback] [--backup]

ENVIRONMENT=""
IMAGE=""
SBOM=""
ROLLBACK=false
BACKUP=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --sbom)
            SBOM="$2"
            shift 2
            ;;
        --rollback)
            ROLLBACK=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# 验证必需参数
if [[ -z "$ENVIRONMENT" ]] || [[ -z "$IMAGE" ]]; then
    log_error "缺少必需参数 --environment 和 --image"
    exit 1
fi

log_info "开始部署到 $ENVIRONMENT"
log_info "使用镜像: $IMAGE"

# 加载环境配置
case $ENVIRONMENT in
    staging)
        K8S_NAMESPACE="warehouse-staging"
        DEPLOYMENT_NAME="warehouse-staging"
        REPLICAS=2
        ;;
    production)
        K8S_NAMESPACE="warehouse-production"
        DEPLOYMENT_NAME="warehouse-production"
        REPLICAS=5
        ;;
    *)
        log_error "未知环境: $ENVIRONMENT"
        exit 1
        ;;
esac

# 备份当前部署
if [[ "$BACKUP" == true ]]; then
    log_info "创建当前部署备份..."
    kubectl get deployment "$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" \
        -o yaml > "backups/${DEPLOYMENT_NAME}-$(date +%Y%m%d-%H%M%S).yaml" || true
fi

# 执行回滚
if [[ "$ROLLBACK" == true ]]; then
    log_warn "执行回滚操作..."
    
    # 获取历史部署
    REVISION=$(kubectl rollout history deployment/"$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" | \
        grep -E "^[0-9]+" | tail -2 | head -1 | awk '{print $1}')
    
    if [[ -n "$REVISION" ]]; then
        kubectl rollout undo deployment/"$DEPLOYMENT_NAME" \
            --to-revision="$REVISION" -n "$K8S_NAMESPACE"
        log_info "回滚到版本 $REVISION"
    else
        log_error "无法获取历史版本"
        exit 1
    fi
    
    kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" --timeout=300s
    log_info "回滚完成"
    exit 0
fi

# 更新镜像
log_info "更新 Kubernetes 部署..."
kubectl set image deployment/"$DEPLOYMENT_NAME" \
    warehouse="$IMAGE" \
    -n "$K8S_NAMESPACE"

# 如果提供了 SBOM，保存为注释
if [[ -n "$SBOM" ]] && [[ -f "$SBOM" ]]; then
    kubectl annotate deployment/"$DEPLOYMENT_NAME" \
        sbom.spdx.io/reference="$(basename "$SBOM")" \
        --overwrite -n "$K8S_NAMESPACE"
fi

# 等待部署完成
log_info "等待部署完成..."
kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" --timeout=600s

# 验证部署
log_info "验证部署..."
READY_REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$K8S_NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}')

if [[ "$READY_REPLICAS" == "$REPLICAS" ]]; then
    log_info "部署成功！就绪副本数: $READY_REPLICAS/$REPLICAS"
else
    log_error "部署失败！就绪副本数: $READY_REPLICAS/$REPLICAS"
    exit 1
fi

# 记录部署历史
log_info "记录部署历史..."
kubectl annotate deployment/"$DEPLOYMENT_NAME" \
    last-deployment="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    last-image="$IMAGE" \
    --overwrite -n "$K8S_NAMESPACE"

log_info "部署到 $ENVIRONMENT 完成！"
