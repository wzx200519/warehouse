# CI/CD 完整设置指南

## 1. 前置条件

### 1.1 GitHub Secrets 配置

在仓库设置中配置以下 Secrets：

| Secret 名称 | 描述 | 示例值 |
|------------|------|--------|
| `REGISTRY_URL` | 容器镜像仓库地址 | `ghcr.io` 或 `docker.io` |
| `REGISTRY_USERNAME` | 仓库用户名 | `your-username` |
| `REGISTRY_PASSWORD` | 仓库密码/Token | `ghp_xxxxx` |
| `DEPLOY_TOKEN` | 部署用的 GitHub Personal Access Token | `ghp_xxxxx` |
| `DEPLOY_REPO` | 部署目标仓库（可选，默认当前仓库） | `your-org/infra` |
| `SLACK_WEBHOOK` | Slack 通知 Webhook URL | `https://hooks.slack.com/...` |
| `AWS_ROLE_ARN` | AWS IAM Role ARN (如使用 AWS) | `arn:aws:iam::xxx:role/xxx` |
| `AWS_REGION` | AWS 区域 | `us-east-1` |
| `ECS_SERVICE_NAME` | ECS 服务名称 (如使用 ECS) | `warehouse-service` |
| `ECS_CLUSTER_NAME` | ECS 集群名称 | `warehouse-cluster` |

### 1.2 GitHub Variables 配置

配置以下 Variables：

| Variable 名称 | 描述 | 值 |
|--------------|------|-----|
| `USE_AWS` | 是否启用 AWS 部署 | `true` 或 `false` |
| `USE_KUBERNETES` | 是否启用 Kubernetes 部署 | `true` 或 `false` |
| `USE_SWARM` | 是否启用 Docker Swarm 部署 | `true` 或 `false` |
| `USE_ECS` | 是否启用 ECS 部署 | `true` 或 `false` |

## 2. 本地开发设置

### 2.1 安装 pre-commit

```bash
pip install pre-commit
pre-commit install
```

### 2.2 手动运行 pre-commit 检查

```bash
pre-commit run --all-files
```

## 3. CI/CD 流程说明

### 3.1 完整流程

```
代码提交 (push/pr)
    ↓
[Build] 构建 Docker 镜像
    ↓
[Test Matrix] 并行运行:
    - Unit Tests (单元测试)
    - Lint Check (代码检查)
    - Documentation (文档检查)
    - Dependencies (依赖检查)
    - Licenses (许可证检查)
    - Translations (翻译检查)
    ↓
[CodeQL] 安全扫描
    ↓
[Check DB] 数据库一致性检查
    ↓
[Push Image] (仅 main 分支) 推送生产镜像
    ↓
[Deploy] (仅 main 分支) 触发部署
```

### 3.2 触发条件

- **push 到 main/develop**: 触发完整 CI/CD 流程
- **PR 到任意分支**: 触发 CI 测试流程（不推送镜像和部署）
- **merge_group**: 合并队列检查
- **workflow_dispatch**: 手动触发

## 4. 工作流文件说明

### 4.1 `.github/workflows/ci-cd.yml`

主要的 CI/CD 流水线，包含：
- `build`: 构建 CI 镜像
- `test`: 测试矩阵（并行运行所有检查）
- `codeql`: 安全分析
- `check-db`: 数据库一致性检查
- `push-image`: 推送生产镜像（仅 main 分支）
- `deploy`: 触发部署（仅 main 分支）

### 4.2 `.github/workflows/deploy.yml`

部署处理工作流，通过 `repository_dispatch` 事件触发，支持：
- Kubernetes 部署
- Docker Swarm 部署
- AWS ECS 部署
- 可自定义的部署流程

### 4.3 `.pre-commit-config.yaml`

增强的 pre-commit 配置，包含：
- 基础文件检查（YAML/TOML 格式、大文件、合并冲突等）
- Python 代码格式化（black、isort）
- Python 代码检查（flake8、bandit 安全扫描）
- JavaScript 检查（eslint）
- GitHub Actions 检查（actionlint）
- 项目特定的本地钩子

## 5. 部署配置

### 5.1 Kubernetes 部署示例

在 `deploy.yml` 中取消注释 Kubernetes 相关部分：

```yaml
- name: Update Kubernetes manifests
  run: |
    sed -i "s|IMAGE_TAG|${{ github.event.client_payload.image_tag }}|g" k8s/deployment.yaml

- name: Deploy to Kubernetes
  run: |
    kubectl apply -f k8s/
    kubectl rollout status deployment/warehouse
```

### 5.2 Docker Swarm 部署示例

```yaml
- name: Deploy to Docker Swarm
  run: |
    docker stack deploy -c docker-compose.prod.yml warehouse
```

### 5.3 AWS ECS 部署

配置 `USE_ECS=true` 并设置相关 Secrets 即可自动启用。

## 6. 回滚策略

### 6.1 回滚到上一个版本

```bash
# 使用 git  revert
git revert HEAD
git push

# 或通过 GitHub UI 创建 revert PR
```

### 6.2 手动触发部署特定版本

通过 `workflow_dispatch` 手动触发 `deploy.yml`，指定要部署的镜像标签。

## 7. 监控和通知

- **Slack 通知**: 部署成功/失败会发送到配置的 Slack 频道
- **GitHub 环境**: 使用 GitHub Environments 管理部署目标和批准流程
- **部署历史**: 在仓库的 Actions 标签页查看完整部署历史

## 8. 故障排查

### 8.1 常见问题

1. **构建失败**: 检查 Dockerfile 和依赖是否正确
2. **测试失败**: 查看测试输出，修复代码问题
3. **推送失败**: 确认 Secrets 配置和权限
4. **部署失败**: 检查目标环境和凭证

### 8.2 获取更多日志

在 GitHub Actions 运行页面点击具体步骤查看详细日志。

## 9. 自定义和扩展

### 9.1 添加新的测试步骤

在 `ci-cd.yml` 的 `test` job 的 `matrix.include` 中添加新项目。

### 9.2 扩展部署流程

修改 `deploy.yml` 添加自定义部署步骤。

### 9.3 添加新的 pre-commit 钩子

在 `.pre-commit-config.yaml` 中添加新的仓库和钩子。

---

**注意**: 首次设置前请确保所有必需的 Secrets 和 Variables 已正确配置！
