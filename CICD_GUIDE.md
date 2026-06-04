# CI/CD Pipeline Documentation

## 概述

本项目实现了一套完整的 CI/CD 流水线，基于 GitHub Actions 实现代码提交后自动执行 Lint、单元测试、安全扫描，并通过 Docker 构建镜像推送到仓库，最后触发部署。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        Git Push/PR                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  1. Lint & Format Check                        │
│  • Pre-commit hooks (Black, isort, Flake8, MyPy, Bandit)       │
│  • Frontend Lint (ESLint, Prettier)                            │
│  • Commit message format validation                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  2. Security Scanning                           │
│  • Bandit (Python 安全扫描)                                     │
│  • Safety (依赖漏洞检查)                                         │
│  • npm audit (Node.js 依赖检查)                                 │
│  • Trivy (容器镜像扫描)                                          │
│  • CodeQL (代码安全分析)                                         │
│  • Zizmor (GitHub Actions 安全扫描)                             │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  3. Unit Tests                                  │
│  • Python 单元测试                                               │
│  • Frontend 静态测试                                             │
│  • 覆盖率报告生成                                                │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  4. Build & Push Docker Image                   │
│  • 多阶段 Docker 构建 (Depot)                                   │
│  • 生成 SBOM (Software Bill of Materials)                       │
│  • 推送镜像到 GHCR                                               │
│  • 生成多种标签 (latest, sha, branch, semver)                   │
└─────────────────────────────┬───────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│   Deploy to Staging     │     │   Deploy to Production  │
│   (Main branch push)    │     │   (Release branches)    │
│   • 蓝绿部署            │     │   • 需手动审批          │
│   • 自动健康检查         │     │   • 蓝绿切换            │
│   • 冒烟测试             │     │   • 完整冒烟测试        │
│   • 自动回滚 (失败时)    │     │   • Slack 通知          │
└─────────────────────────┘     └─────────────────────────┘
```

## 配置文件说明

### 1. GitHub Actions 工作流

#### `.github/workflows/cicd.yml` - 主 CI/CD 流程
包含以下作业：
- `lint-and-format`: 代码质量检查
- `security-scan`: 安全扫描 (矩阵作业)
- `unit-tests`: 单元测试
- `build-and-push`: Docker 镜像构建和推送
- `deploy-staging`: 部署到 Staging 环境
- `deploy-production`: 部署到 Production 环境
- `rollback`: 自动回滚机制
- `deployment-report`: 生成部署报告

#### `.github/workflows/codeql-analysis.yml` - CodeQL 安全分析
- Python 代码分析
- JavaScript 代码分析
- GitHub Actions 工作流分析

#### `.github/workflows/zizmor.yml` - GitHub Actions 安全扫描
- 使用 Zizmor 工具扫描 Actions 工作流

### 2. Pre-commit 配置

#### `.pre-commit-config.yaml`
包含以下钩子：

**Pre-commit 阶段:**
- Black (Python 格式化)
- isort (Import 排序)
- Flake8 (Python Lint)
- MyPy (类型检查)
- Bandit (安全扫描)
- ESLint (JavaScript Lint)
- Prettier (代码格式化)
- Hadolint (Dockerfile 检查)
- detect-secrets (敏感信息检测)

**Commit-msg 阶段:**
- Commit message 格式验证 (Conventional Commits)

**Pre-push 阶段:**
- 运行单元测试

### 3. 部署脚本

#### `scripts/deploy.sh`
功能：
- 支持 Staging 和 Production 环境
- 自动备份当前部署
- Kubernetes 部署更新
- 回滚到上一版本
- 部署验证

#### `scripts/deploy-switch.sh`
功能：
- 蓝绿部署切换
- 流量切换
- 旧部署清理

#### `scripts/smoke-tests.sh`
功能：
- 健康检查端点测试
- 主页可访问性测试
- API 响应测试
- SSL 证书验证
- 响应时间测试

#### `scripts/quality-check.sh`
功能：
- Python 代码质量检查
- 安全检查
- 前端代码检查

### 4. Kubernetes 配置

#### `k8s/warehouse-staging.yaml`
- Deployment 配置
- Service 配置
- Ingress 配置
- HPA (水平 Pod 自动扩缩容)

#### `k8s/warehouse-production-bluegreen.yaml`
- 蓝绿部署配置
- Blue 和 Green 两个槽位
- 通过 Service selector 切换流量

### 5. 环境配置

#### `.github/environments/`
- `staging.yml`: Staging 环境配置
- `production.yml`: Production 环境配置

## 设置步骤

### 1. 安装 Pre-commit Hooks

```bash
# 安装 pre-commit
pip install pre-commit

# 安装 hooks
pre-commit install

# 安装 commit-msg hook
pre-commit install --hook-type commit-msg

# 安装 pre-push hook
pre-commit install --hook-type pre-push
```

### 2. 配置 GitHub Secrets

在 GitHub 仓库 Settings > Secrets and variables > Actions 中添加：

```
# Kubernetes 配置
KUBECONFIG - Base64 编码的 kubeconfig

# Slack 通知
SLACK_WEBHOOK_URL - Slack Incoming Webhook URL

# 审批配置
GH_APPROVAL_TOKEN - Personal Access Token
REQUIRED_APPROVERS - 审批者列表

# AWS 配置 (如使用)
AWS_ACCOUNT_ID
AWS_REGION
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

### 3. 创建 GitHub Environments

在 GitHub 仓库 Settings > Environments 中创建：

**Staging:**
- 设置为 staging 环境
- 配置保护规则 (可选)

**Production:**
- 设置为 production 环境
- 添加必需的审批者
- 配置等待时间

### 4. 配置容器 Registry

默认使用 GitHub Container Registry (ghcr.io)，无需额外配置。
如需使用其他 Registry，在 Secrets 中配置相应的认证信息。

## 使用方法

### 自动触发

流水线会在以下情况自动触发：

1. **PR 创建/更新**: 运行 Lint、测试、安全扫描
2. **Main 分支推送**: 运行完整 CI/CD 并部署到 Staging
3. **Release 分支推送**: 运行完整 CI/CD 并部署到 Production
4. **手动触发**: 可选择环境和跳过测试

### 手动部署

通过 GitHub Actions 手动触发：

1. 进入 Actions 页面
2. 选择 "CI/CD Pipeline"
3. 点击 "Run workflow"
4. 选择环境 (staging/production)
5. 可选择跳过测试

### 回滚

回滚自动发生：
- Staging 部署失败时自动回滚

手动回滚：
```bash
# 使用 deploy.sh 脚本
./scripts/deploy.sh \
  --environment staging \
  --image ghcr.io/pypi/warehouse:<previous-tag> \
  --rollback
```

## 环境变量

### GitHub Actions 环境变量

```yaml
REGISTRY: ghcr.io
IMAGE_NAME: ${{ github.repository }}
PYTHON_VERSION: '3.14'
NODE_VERSION: '25.6.0'
```

### 部署环境变量

在 Kubernetes Deployment 中配置：

```yaml
ENVIRONMENT: staging|production
DATABASE_URL: 数据库连接字符串
REDIS_URL: Redis 连接字符串
GIT_SHA: 当前 commit SHA
```

## 监控和通知

### Slack 通知

部署状态会自动发送到 Slack：
- Staging 部署状态
- Production 部署状态
- 回滚触发通知

### 构建产物

CI/CD 生成的产物保存在 GitHub Actions Artifacts 中：

- `lint-results`: Lint 检查结果
- `test-results`: 测试结果和覆盖率报告
- `security-scan-*`: 安全扫描结果
- `sbom`: SBOM 文件
- `deployment-report`: 部署报告

## 安全最佳实践

1. **Secret 管理**: 所有密钥存储在 GitHub Secrets
2. **权限最小化**: CI 使用最小必需权限
3. **代码签名**: Docker 镜像使用 Git SHA 标签
4. **SBOM 追踪**: 记录每个部署的依赖清单
5. **多层扫描**: 包含代码、依赖、容器多层次安全扫描
6. **审批流程**: Production 部署需要手动审批
7. **蓝绿部署**: 减少部署风险，支持快速回滚

## 故障排查

### Lint 失败

```bash
# 本地运行 lint
make lint

# 修复格式问题
make reformat

# 本地运行静态 lint
make static_lint
```

### 测试失败

```bash
# 本地运行测试
make tests

# 运行特定测试
make tests T="test_module.py::test_function"
```

### 部署失败

1. 检查 GitHub Actions 日志
2. 验证 Kubernetes 配置
3. 检查容器镜像是否正确推送
4. 验证环境变量配置

### 安全扫描警告

- **Bandit**: 查看具体的安全问题并修复
- **Safety**: 更新有漏洞的依赖
- **npm audit**: 运行 `npm audit fix`
- **Trivy**: 确保基础镜像已更新

## 维护

### 更新依赖

```bash
# 更新 Python 依赖
pip-review --auto

# 更新 Node.js 依赖
npm update

# 更新 pre-commit hooks
pre-commit autoupdate
```

### 更新 Docker 镜像版本

在 `cicd.yml` 中更新：
- `PYTHON_VERSION`
- `NODE_VERSION`

### 更新 CI 配置

编辑对应的 `.github/workflows/*.yml` 文件，提交后会自动触发 CI。

## 参考链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Depot 文档](https://depot.dev/docs)
- [Pre-commit 文档](https://pre-commit.com/)
- [Kubernetes 部署策略](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [蓝绿部署](https://martinfowler.com/bliki/BlueGreenDeployment.html)
