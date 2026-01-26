#!/bin/bash
# client-setup.sh - SSH内网穿透客户端配置脚本
# 在内网机器上运行

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 打印横幅
print_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    SSH内网穿透客户端一键配置脚本"
    echo "=========================================="
    echo -e "${NC}"
}

# 检查并安装必要软件
install_dependencies() {
    log_step "检查必要软件..."

    if ! command -v ssh; then
        log_warn "SSH客户端未安装，正在安装..."
        if command -v apt-get; then
            apt-get update
            apt-get install -y openssh-client autossh
        elif command -v yum; then
            yum install -y openssh-clients autossh
        elif command -v dnf; then
            dnf install -y openssh-clients autossh
        else
            log_error "无法自动安装SSH客户端，请手动安装"
            exit 1
        fi
    fi

    if ! command -v autossh; then
        log_warn "安装autossh以保持连接稳定..."
        if command -v apt-get; then
            apt-get install -y autossh
        elif command -v yum; then
            yum install -y autossh
        fi
    fi

    log_info "必要软件检查完成"
}

# 生成SSH密钥
generate_ssh_key() {
    log_step "生成SSH密钥对..."

    if [ ! -f ~/.ssh/id_rsa ]; then
        read -p "是否生成新的SSH密钥? (y/n, 默认为y): " generate
        if [[ $generate != "n" ]]; then
            ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
            log_info "SSH密钥已生成"
        fi
    else
        log_info "SSH密钥已存在"
    fi

    echo "公钥内容:"
    echo "=========================================="
    cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "未找到公钥文件"
    echo "=========================================="

    log_info "请将上述公钥复制到服务端的 ~/.ssh/authorized_keys 文件中"
}

# 配置SSH客户端
configure_ssh_client() {
    log_step "配置SSH客户端..."

    read -p "请输入VPS服务器IP地址: " vps_ip
    read -p "请输入VPS服务器SSH端口 (默认为22): " vps_port
    vps_port=${vps_port:-22}
    read -p "请输入VPS服务器用户名 (默认为root): " vps_user
    vps_user=${vps_user:-root}

    # 测试连接
    log_info "测试SSH连接..."
    if ssh -p $vps_port $vps_user@$vps_ip "echo '连接成功!'"; then
        log_info "SSH连接测试成功"
    else
        log_warn "SSH连接测试失败，请检查配置"
    fi

    # 保存配置到SSH config
    SSH_CONFIG="$HOME/.ssh/config"
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    cat >> "$SSH_CONFIG" << EOF

# VPS服务器配置
Host vps-tunnel
    HostName $vps_ip
    User $vps_user
    Port $vps_port
    ServerAliveInterval 60
    ServerAliveCountMax 3
    IdentityFile ~/.ssh/id_rsa
EOF

    log_info "SSH配置已保存到 ~/.ssh/config"
    log_info "可以使用 'ssh vps-tunnel' 测试连接"
}

# 创建隧道配置
create_tunnel_config() {
    log_step "创建隧道配置..."

    CONFIG_DIR="$HOME/.ssh-tunnel"
    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_DIR/config.sh" << 'EOF'
#!/bin/bash
# SSH隧道配置文件

# VPS服务器配置
VPS_HOST="vps-tunnel"  # 对应 ~/.ssh/config 中的Host
LOCAL_IP="localhost"

# 隧道配置数组
# 格式: "隧道名称:本地端口:远程端口:类型"
# 类型: reverse(反向) 或 forward(正向)
TUNNELS=(
    "web:80:8080:reverse"
    "ssh:22:2222:reverse"
    "mysql:3306:3306:reverse"
    "rdp:3389:3389:reverse"
)

# 自动重连配置
AUTOSSH_OPTS="-M 0 -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -o 'ExitOnForwardFailure=yes'"
EOF

    log_info "隧道配置文件已创建: $CONFIG_DIR/config.sh"
}

# 创建隧道管理脚本
create_tunnel_manager() {
    log_step "创建隧道管理脚本..."

    cat > ~/ssh-tunnel-manager.sh << 'EOF'
#!/bin/bash
# SSH隧道管理脚本

CONFIG_DIR="$HOME/.ssh-tunnel"
CONFIG_FILE="$CONFIG_DIR/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件不存在: $CONFIG_FILE"
    echo "请先运行配置脚本"
    exit 1
fi

source "$CONFIG_FILE"

# 检查参数
if [ $# -lt 1 ]; then
    echo "用法: $0 {start|stop|restart|status|list|add|remove}"
    exit 1
fi

case "$1" in
    start)
        if [ $# -eq 1 ]; then
            # 启动所有隧道
            for tunnel in "${TUNNELS[@]}"; do
                IFS=':' read -r name local_port remote_port type <<< "$tunnel"

                pid_file="$CONFIG_DIR/$name.pid"
                log_file="$CONFIG_DIR/$name.log"

                if [ "$type" == "reverse" ]; then
                    cmd="autossh $AUTOSSH_OPTS -fN -R $remote_port:$LOCAL_IP:$local_port $VPS_HOST"
                else
                    cmd="autossh $AUTOSSH_OPTS -fN -L $remote_port:$LOCAL_IP:$local_port $VPS_HOST"
                fi

                echo "启动隧道: $name (本地:$local_port -> 远程:$remote_port)"
                eval $cmd
                echo $! > "$pid_file"
            done
        else
            # 启动指定隧道
            tunnel_name="$2"
            for tunnel in "${TUNNELS[@]}"; do
                IFS=':' read -r name local_port remote_port type <<< "$tunnel"
                if [ "$name" == "$tunnel_name" ]; then
                    pid_file="$CONFIG_DIR/$name.pid"
                    log_file="$CONFIG_DIR/$name.log"

                    if [ "$type" == "reverse" ]; then
                        cmd="autossh $AUTOSSH_OPTS -fN -R $remote_port:$LOCAL_IP:$local_port $VPS_HOST"
                    else
                        cmd="autossh $AUTOSSH_OPTS -fN -L $remote_port:$LOCAL_IP:$local_port $VPS_HOST"
                    fi

                    echo "启动隧道: $name"
                    eval $cmd
                    echo $! > "$pid_file"
                    break
                fi
            done
        fi
        ;;

    stop)
        if [ $# -eq 1 ]; then
            # 停止所有隧道
            for pid_file in "$CONFIG_DIR"/*.pid; do
                if [ -f "$pid_file" ]; then
                    pid=$(cat "$pid_file")
                    name=$(basename "$pid_file" .pid)
                    echo "停止隧道: $name (PID: $pid)"
                    kill "$pid" 2>/dev/null
                    rm -f "$pid_file"
                fi
            done
        else
            # 停止指定隧道
            tunnel_name="$2"
            pid_file="$CONFIG_DIR/$tunnel_name.pid"
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file")
                echo "停止隧道: $tunnel_name (PID: $pid)"
                kill "$pid" 2>/dev/null
                rm -f "$pid_file"
            else
                echo "隧道未运行: $tunnel_name"
            fi
        fi
        ;;

    restart)
        $0 stop
        sleep 2
        $0 start
        ;;

    status)
        echo "隧道状态:"
        echo "=========="
        for pid_file in "$CONFIG_DIR"/*.pid; do
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file")
                name=$(basename "$pid_file" .pid)
                if ps -p "$pid" > /dev/null; then
                    echo "[运行中] $name (PID: $pid)"
                else
                    echo "[已停止] $name"
                    rm -f "$pid_file"
                fi
            fi
        done

        echo "配置的隧道:"
        for tunnel in "${TUNNELS[@]}"; do
            IFS=':' read -r name local_port remote_port type <<< "$tunnel"
            echo "  - $name: 本地$local_port -> 远程$remote_port ($type)"
        done
        ;;

    list)
        echo "可用隧道:"
        for tunnel in "${TUNNELS[@]}"; do
            IFS=':' read -r name local_port remote_port type <<< "$tunnel"
            echo "  $name: $LOCAL_IP:$local_port -> $VPS_HOST:$remote_port ($type)"
        done
        ;;

    add)
        if [ $# -lt 5 ]; then
            echo "用法: $0 add <名称> <本地端口> <远程端口> <类型>"
            echo "类型: reverse(反向) 或 forward(正向)"
            exit 1
        fi

        new_tunnel="$2:$3:$4:$5"

        # 检查是否已存在
        for tunnel in "${TUNNELS[@]}"; do
            IFS=':' read -r name _ _ _ <<< "$tunnel"
            if [ "$name" == "$2" ]; then
                echo "错误: 隧道名称 '$2' 已存在"
                exit 1
            fi
        done

        # 添加到配置文件
        echo "TUNNELS+=(\"$new_tunnel\")" >> "$CONFIG_FILE"
        echo "隧道已添加: $new_tunnel"

        # 重新加载配置
        source "$CONFIG_FILE"
        ;;

    remove)
        if [ $# -lt 2 ]; then
            echo "用法: $0 remove <隧道名称>"
            exit 1
        fi

        # 停止隧道
        $0 stop "$2"

        # 创建临时配置文件
        temp_file=$(mktemp)
        grep -v "^TUNNELS+=.*\"$2:" "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"

        echo "隧道 '$2' 已从配置中移除"

        # 重新加载配置
        source "$CONFIG_FILE"
        ;;

    *)
        echo "未知命令: $1"
        echo "用法: $0 {start|stop|restart|status|list|add|remove}"
        exit 1
        ;;
esac
EOF

    chmod +x ~/ssh-tunnel-manager.sh
    log_info "隧道管理脚本已创建: ~/ssh-tunnel-manager.sh"
}

# 创建系统服务（可选）
create_system_service() {
    log_step "创建系统服务（可选）..."

    read -p "是否创建系统服务以便开机自启? (y/n): " create_service
    if [[ $create_service == "y" ]]; then
        if [ "$EUID" -eq 0 ]; then
            SERVICE_FILE="/etc/systemd/system/ssh-tunnel.service"

            cat > "$SERVICE_FILE" << EOF
[Unit]
Description=SSH Tunnel Service
After=network.target

[Service]
Type=forking
User=$SUDO_USER
ExecStart=/home/$SUDO_USER/ssh-tunnel-manager.sh start
ExecStop=/home/$SUDO_USER/ssh-tunnel-manager.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable ssh-tunnel.service

            log_info "系统服务已创建并启用"
            log_info "管理命令:"
            log_info "  sudo systemctl start ssh-tunnel"
            log_info "  sudo systemctl stop ssh-tunnel"
            log_info "  sudo systemctl status ssh-tunnel"
        else
            log_warn "需要root权限创建系统服务"
            log_info "您可以手动创建服务或使用cron定时任务"
        fi
    fi
}

# 显示使用说明
show_usage() {
    log_step "使用说明"
    echo "=========================================="
    echo "隧道管理命令:"
    echo "  ./ssh-tunnel-manager.sh start      # 启动所有隧道"
    echo "  ./ssh-tunnel-manager.sh stop       # 停止所有隧道"
    echo "  ./ssh-tunnel-manager.sh status     # 查看隧道状态"
    echo "  ./ssh-tunnel-manager.sh list       # 列出所有隧道"
    echo "  ./ssh-tunnel-manager.sh add        # 添加新隧道"
    echo "  ./ssh-tunnel-manager.sh remove     # 移除隧道"
    echo ""
    echo "示例隧道:"
    echo "  1. 暴露本地Web服务到VPS的8080端口:"
    echo "     ./ssh-tunnel-manager.sh add web 80 8080 reverse"
    echo "     ./ssh-tunnel-manager.sh start web"
    echo ""
    echo "  2. 通过VPS访问内网RDP服务:"
    echo "     ./ssh-tunnel-manager.sh add rdp 3389 3389 reverse"
    echo ""
    echo "配置文件位置: ~/.ssh-tunnel/config.sh"
    echo "=========================================="
}

# 主函数
main() {
    print_banner

    log_info "开始配置SSH内网穿透客户端..."

    # install_dependencies
    # generate_ssh_key
    # configure_ssh_client
    # create_tunnel_config
    # create_tunnel_manager
    create_system_service
    show_usage

    log_info "客户端配置完成!"
    log_info "请确保已将公钥复制到VPS服务器的 authorized_keys 文件中"
    log_info "然后使用 ./ssh-tunnel-manager.sh start 启动隧道"
}

# 执行主函数
main "$@"
