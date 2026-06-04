# Dockerfile 优化建议
# 为支持完整的 CI/CD 流程，建议在 Dockerfile 中添加以下优化

## 1. 多阶段构建优化 (已有)

当前 Dockerfile 已使用多阶段构建，包含：
- `static-deps`: Node.js 依赖阶段
- `static`: 静态资源构建阶段
- `base`: Python 基础阶段
- `builder`: 依赖安装阶段
- `dev`: 开发环境阶段
- `worker`: Worker 服务阶段
- `web`: Web 服务阶段

## 2. 建议添加的优化

### 2.1 添加构建参数用于 CI/CD

```dockerfile
# 在顶部添加
ARG CI=false
ARG GIT_SHA=unknown
ARG GIT_REF=unknown

# 在 web 阶段添加标签
LABEL org.opencontainers.image.revision=$GIT_SHA
LABEL org.opencontainers.image.ref.name=$GIT_REF
LABEL ci.build=$CI
```

### 2.2 优化依赖缓存

```dockerfile
# 在 builder 阶段优化
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements/main.txt

# 在 static-deps 阶段优化 (已有)
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm ci
```

### 2.3 添加健康检查

```dockerfile
# 在 web 服务添加
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1
```

### 2.4 添加非 root 用户 (安全加固)

```dockerfile
# 在 base 阶段添加
RUN groupadd --gid 1000 warehouse && \
    useradd --uid 1000 --gid warehouse --shell /bin/bash --create-home warehouse

# 在 web 阶段切换用户
USER warehouse
```

### 2.5 完整的健康检查端点配置

```dockerfile
# 在 web 阶段的 ENTRYPOINT 或 CMD 前添加
ENV HEALTHCHECK_PATH=/health
ENV PORT=8000

# 或使用 exec form 添加健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}${HEALTHCHECK_PATH}')"
```

## 3. 推荐的 Dockerfile 片段

```dockerfile
# ====================
# 建议在现有 Dockerfile 中添加的优化
# ====================

# 1. 构建参数 (在 FROM 之后添加)
ARG CI=false
ARG GIT_SHA=unknown
ARG GIT_REF=unknown

# 2. 元数据标签 (在 web 阶段的适当位置)
LABEL maintainer="PyPA <infra@pypi.org>"
LABEL org.opencontainers.image.source="https://github.com/pypi/warehouse"
LABEL org.opencontainers.image.revision=$GIT_SHA
LABEL org.opencontainers.image.ref.name=$GIT_REF
LABEL ci.build=$CI

# 3. 非 root 用户 (在 base 阶段添加)
RUN groupadd --gid 1000 warehouse && \
    useradd --uid 1000 --gid warehouse --shell /bin/bash --create-home warehouse

# 4. 安全配置 (在 web 阶段)
# 使用 read-only root filesystem
USER warehouse
WORKDIR /home/warehouse

# 5. 健康检查 (在 web 阶段的服务中添加)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 6. 信号处理 (确保优雅关闭)
STOPSIGNAL SIGTERM
```

## 4. CI/CD 专用的 Dockerfile.variant

如需为 CI/CD 创建专门的构建配置：

```dockerfile
# Dockerfile.ci
# 用于 CI/CD 的精简版本

FROM python:3.14.5-slim-trixie AS base

# 安装最小依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制依赖文件
COPY requirements/main.txt requirements/deploy.txt ./

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements/main.txt -r requirements/deploy.txt

# 复制应用代码
COPY warehouse/ ./warehouse/

# 非 root 用户
RUN useradd -m appuser
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["python", "-m", "warehouse"]
```

## 5. GitHub Actions 中的构建优化

在 `.github/workflows/cicd.yml` 中使用 Depot 构建缓存：

```yaml
- name: Build and push with Depot
  uses: depot/build-push-action@v1
  with:
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    build-args: |
      CI=yes
      GIT_SHA=${{ github.sha }}
    # 使用 GitHub Actions 缓存
    cache-from: ghcr.io/${{ github.repository }}:latest
    cache-to: type=gha,mode=max
```

## 6. Docker Compose 用于本地开发

```yaml
# docker-compose.ci.yml
# 用于 CI 环境的 Docker Compose 配置

services:
  warehouse:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CI: "yes"
    environment:
      CI: "yes"
      DATABASE_URL: postgresql://postgres@db/warehouse
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
```

## 7. 镜像签名和验证

为确保镜像安全，建议添加镜像签名：

```dockerfile
# 在 Dockerfile 末尾添加 (需要 Cosign)
RUN apt-get update && apt-get install -y curl && \
    curl -sSfL https://docs.sigstore.dev.cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign && \
    rm -rf /var/lib/apt/lists/*
```

在 CI/CD 中签名镜像：

```yaml
- name: Sign image with Cosign
  uses: sigstore/cosign-installer@v3
  with:
    cosign-version: 'v2'

- name: Sign and push image
  run: |
    cosign sign --yes ghcr.io/${{ github.repository }}:${{ github.sha }}
  env:
    COSIGN_EXPERIMENTAL: "1"
    COSIGN_YES: "true"
```

## 8. 最佳实践总结

1. **使用多阶段构建** - 减小镜像大小
2. **利用构建缓存** - 加速构建过程
3. **使用轻量级基础镜像** - Python slim 镜像
4. **避免安装不必要的包** - 使用 --no-install-recommends
5. **使用非 root 用户** - 提高安全性
6. **添加健康检查** - 便于容器编排
7. **清理缓存和临时文件** - 减小镜像大小
8. **标签和元数据** - 便于追踪
9. **使用 BuildKit 特性** - 现代 Docker 构建
10. **镜像签名** - 确保镜像来源可信
