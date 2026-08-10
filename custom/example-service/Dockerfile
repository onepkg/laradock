# example-service —— 自定义服务模板
# 使用：复制本目录为 custom/<你的服务>/，修改 Dockerfile 与
# docker-compose.custom.yml 中对应服务块（build.context / 服务名）。
# 注意：该服务带 restart: always，镜像必须包含前台长驻进程，
# 否则容器会不断重启（crash-loop）。
FROM alpine:3.20

RUN apk add --no-cache bash

# 卷轴 example-data 挂载于 /data，用于持久化
WORKDIR /data

# 占位长驻进程：替换为你的真实入口
CMD ["sh", "-c", "echo '[example-service] placeholder, replace CMD in custom/example-service/Dockerfile'; while true; do sleep 3600; done"]
