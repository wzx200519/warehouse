# Secret Scanning 配置
# 确保在 GitHub 仓库 Settings > Security > Secret scanning 中启用

# 为 CI/CD 添加必要的 Secrets
# 在 GitHub 仓库 Settings > Secrets and variables > Actions 中添加:

# AWS 部署凭据 (示例)
# AWS_ACCOUNT_ID: 生产环境 AWS 账户 ID
# AWS_REGION: 部署区域 (如 us-east-1)
# AWS_ACCESS_KEY_ID: AWS 访问密钥
# AWS_SECRET_ACCESS_KEY: AWS 密钥

# Kubernetes 部署凭据
# KUBECONFIG: Base64 编码的 kubeconfig 文件内容

# Slack 通知
# SLACK_WEBHOOK_URL: Slack Incoming Webhook URL

# 回滚审批
# GH_APPROVAL_TOKEN: 用于手动审批的 GitHub Personal Access Token
# REQUIRED_APPROVERS: 必需的审批者列表 (逗号分隔)

# Docker Registry
# 使用 GITHUB_TOKEN 自动访问 ghcr.io
# 如需其他 registry，添加对应的 secrets
