ARG LARADOCK_GOLANG_VERSION
# 开发阶段镜像（基于 Debian bullseye，兼容更多依赖编译）
FROM golang:${LARADOCK_GOLANG_VERSION}-bullseye AS dev

# 国内用户必配：Go 代理（加速依赖下载）
ENV GOPROXY=https://goproxy.cn,direct \
    GOSUMDB=sum.golang.org \
    GOPATH=/go \
    GOROOT=/usr/local/go \
    PATH=$PATH:$GOPATH/bin:$GOROOT/bin

RUN sed -i "s@http://deb.debian.org@https://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list

# 安装开发依赖工具：air（热重载）、delve（调试）、git（拉取依赖）、gcc（编译C依赖）
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    gcc \
    make \
    && go install github.com/air-verse/air@v1.62.0 \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 设置工作目录（容器内项目根目录）
WORKDIR /app

# 开发阶段启动命令：用 air 启动服务（支持热重载）
CMD ["air", "-c", ".air.toml"]
