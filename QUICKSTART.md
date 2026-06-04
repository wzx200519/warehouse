# 快速开始指南

## 创建的文件和修改

### 1. GitHub Actions 工作流 (新建)

#### `.github/workflows/cicd.yml`
完整的 CI/CD 流水线工作流，包含：
- Lint 和格式检查
- 安全扫描 (Bandit, Safety, npm audit, Trivy)
- 单元测试
- Docker 镜像构建和推送
- Staging 环境部署
- Production 环境部署
- 自动回滚机制
- 部署报告生成

#### `.github/workflows/codeql-analysis.yml`
CodeQL 安全分析 (已存在，已分析)

#### `.github/workflows/zizmor.yml`
GitHub Actions 安全扫描 (已存在，已分析)

### 2. 环境配置 (新建)

#### `.github/environments/staging.yml`
Staging 环境配置和保护规则

#### `.github/environments/production.yml`
Production 环境配置和保护规则

### 3. 部署脚本 (新建)

#### `scripts/deploy.sh`
Kubernetes 部署脚本，支持：
- Staging/Production 环境
- 镜像更新
- 自动备份
- 回滚功能
- 部署验证

#### `scripts/deploy-switch.sh`
蓝绿部署切换脚本

#### `scripts/smoke-tests.sh`
冒烟测试脚本，包含：
- 健康检查
- 响应时间测试
- SSL 证书验证
- API 可用性测试

#### `scripts/quality-check.sh`
代码质量检查脚本

### 4. Kubernetes 配置 (新建)

#### `k8s/warehouse-staging.yaml`
Staging 环境的完整 K8s 配置：
- Deployment
- Service
- Ingress
- HorizontalPodAutoscaler

#### `k8s/warehouse-production-bluegreen.yaml`
Production 环境的蓝绿部署配置

### 5. Pre-commit 配置 (更新)

#### `.pre-commit-config.yaml`
增强的 pre-commit 配置，新增：
- Black 代码格式化
- isort 导入排序
- Flake8 代码检查
- MyPy 类型检查
- Bandit 安全扫描
- ESLint 前端检查
- Prettier 格式化
- Hadolint Dockerfile 检查
- detect-secrets 敏感信息检测
- ShellCheck 脚本检查
- Commit message 格式验证
- Pre-push 测试

### 6. 文档 (新建)

#### `CICD_GUIDE.md`
完整的 CI/CD 流程文档，包含：
- 架构概览
- 配置文件说明
- 设置步骤
- 使用方法
- 监控和通知
- 安全最佳实践
- 故障排查
- 维护指南

#### `DOCKERFILE_OPTIMIZATION.md`
Dockerfile 优化建议文档

#### `.github/SECRETS.md`
Secret 配置指南

## 部署步骤

### 步骤 1: 启用 Pre-commit Hooks

```bash
cd /app/warehouse-repo

# 安装 pre-commit
pip install pre-commit

# 安装所有 hooks
pre-commit install

# 安装 commit-msg hook
pre-commit install --hook-type commit-msg

# 安装 pre-push hook
pre-commit install --hook-type pre-push
```

### 步骤 2: 配置 GitHub Secrets

在 GitHub 仓库 Settings > Secrets and variables > Actions 中添加：

```bash
# Kubernetes 配置 (Base64 编码)
KUBECONFIG=<base64-encoded-kubeconfig>

# Slack 通知
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx

# 审批配置
GH_APPROVAL_TOKEN=<personal-access-token>
REQUIRED_APPROVERS=<username1>,<username2>
```

### 步骤 3: 创建 GitHub Environments

在 GitHub 仓库 Settings > Environments 中：

1. 点击 "New environment"
2. 创建 `staging` 环境
3. 创建 `production` 环境
4. 配置保护规则和审批者

### 步骤 4: 配置 Kubernetes

```bash
# 应用 Staging 配置
kubectl apply -f k8s/warehouse-staging.yaml

# 应用 Production 配置
kubectl apply -f k8s/warehouse-production-bluegreen.yaml

# 创建 secrets
kubectl create secret generic warehouse-secrets \
  --from-literal=database-url="postgresql://..." \
  --namespace=warehouse-staging

kubectl create secret generic warehouse-secrets \
  --from-literal=database-url="postgresql://..." \
  --namespace=warehouse-production
```

### 步骤 5: 验证 CI/CD 流程

```bash
# 本地测试 pre-commit
pre-commit run --all-files

# 推送代码触发 CI
git add .
git commit -m "feat: 配置完整的 CI/CD 流水线"
git push origin main
```

## 工作流触发条件

| 事件 | 触发的工作 |
|------|-----------|
| PR 创建/更新 | Lint + 测试 + 安全扫描 |
| Main 分支推送 | 完整 CI/CD → 自动部署到 Staging |
| Release 分支推送 | 完整 CI/CD → 部署到 Production (需审批) |
| 手动触发 | 可选择环境和跳过测试 |

## 环境说明

- **Staging**: 用于测试和验证，每次 main 分支合并自动部署
- **Production**: 生产环境，需要 release 分支或手动审批才能部署

## 通知配置

部署状态会通过 Slack webhook 发送通知：
- ✓ Staging 部署成功
- ✓ Production 部署成功
- ⚠️ 回滚触发

## 安全特性

1. 多层安全扫描 (CodeQL, Bandit, Safety, Trivy, npm audit)
2. 敏感信息检测 (detect-secrets)
3. 强制代码审查 (PR 必须通过 CI)
4. 生产环境审批机制
5. 蓝绿部署减少风险
6. 自动回滚机制
7. SBOM 追踪依赖

## 监控

CI/CD 生成的产物保存在 GitHub Actions Artifacts：
- `lint-results`: Lint 报告
- `test-results`: 测试和覆盖率
- `security-scan-*`: 安全扫描结果
- `sbom`: 软件材料清单
- `deployment-report`: 部署报告

## 故障排查

### 查看 CI 日志
1. 进入 GitHub Actions 页面
2. 选择失败的 workflow
3. 查看详细日志

### 本地复现

```bash
# Lint 检查
make lint
make static_lint

# 运行测试
make tests

# 质量检查
./scripts/quality-check.sh

# 冒烟测试
./scripts/smoke-tests.sh --environment staging
```

### 回滚

```bash
# 自动回滚 (Staging 失败时)
# 或手动回滚

./scripts/deploy.sh \
  --environment staging \
  --image ghcr.io/pypi/warehouse:<previous-tag> \
  --rollback
```

## 维护

### 更新依赖

```bash
# 更新 pre-commit hooks
pre-commit autoupdate

# 更新 Python 依赖
pip install -U -r requirements/*.txt

# 更新 Node.js 依赖
npm update
```

### 更新 CI 配置

直接编辑 `.github/workflows/*.yml` 文件，提交后会自动触发。

## 支持

如有问题，请查看：
- `CICD_GUIDE.md` - 完整文档
- `DOCKERFILE_OPTIMIZATION.md` - Dockerfile 优化建议
- GitHub Actions 运行日志
