# headroom —— 自定义工具服务（骨架）
# 占位实现：后续将 FROM、依赖安装和启动逻辑替换为真实内容。
# 注意：该服务带 restart: always，镜像必须包含前台长驻进程，
# 否则容器会不断重启（crash-loop）。
FROM alpine:3.20

RUN apk add --no-cache bash

# 卷轴 headroom-data 挂载于 /data，用于持久化
WORKDIR /data

# 占位长驻进程：后续替换为你的真实入口
CMD ["sh", "-c", "echo '[headroom] skeleton placeholder, replace CMD in custom/headroom/Dockerfile'; while true; do sleep 3600; done"]
