#!/bin/bash
# vps-setup.sh - SSH内网穿透服务端配置脚本
# 需要在有公网IP的VPS服务器上运行

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

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 打印横幅
print_banner() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    SSH内网穿透服务端一键配置脚本"
    echo "=========================================="
    echo -e "${NC}"
}

# 安装必要软件
install_dependencies() {
    log_step "安装必要软件..."

    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y openssh-server ufw autossh cron
    elif command -v yum &> /dev/null; then
        yum install -y openssh-server firewalld autossh cronie
    elif command -v dnf &> /dev/null; then
        dnf install -y openssh-server firewalld autossh cronie
    else
        log_error "不支持的包管理器"
        exit 1
    fi

    log_info "软件安装完成"
}

# 配置SSH服务
configure_ssh() {
    log_step "配置SSH服务..."

    SSH_CONFIG="/etc/ssh/sshd_config"

    # 备份原始配置
    cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"

    # 启用必要的SSH选项
    sed -i 's/#GatewayPorts no/GatewayPorts yes/g' "$SSH_CONFIG"
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' "$SSH_CONFIG"
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 60/g' "$SSH_CONFIG"
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 3/g' "$SSH_CONFIG"

    # 禁用密码登录（推荐使用密钥）
    read -p "是否禁用密码登录? (y/n, 默认为n): " disable_password
    if [[ $disable_password == "y" ]]; then
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' "$SSH_CONFIG"
        log_info "已禁用密码登录"
    fi

    # 修改SSH端口
    read -p "是否修改SSH端口? (y/n, 默认为n): " change_port
    if [[ $change_port == "y" ]]; then
        read -p "请输入新的SSH端口 (1024-65535): " ssh_port
        if [[ $ssh_port =~ ^[0-9]+$ ]] && [ $ssh_port -ge 1024 ] && [ $ssh_port -le 65535 ]; then
            sed -i "s/#Port 22/Port $ssh_port/g" "$SSH_CONFIG"
            log_info "SSH端口已修改为: $ssh_port"
        else
            log_warn "端口号无效，保持默认端口22"
        fi
    fi

    # 重启SSH服务
    systemctl restart sshd
    systemctl enable sshd

    log_info "SSH配置完成"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."

    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian使用ufw
        ufw --force enable
        ufw allow 22/tcp
        log_info "防火墙已启用，SSH端口已开放"

        # 询问是否需要开放其他端口
        read -p "是否要开放其他端口用于内网穿透? (y/n): " open_more_ports
        while [[ $open_more_ports == "y" ]]; do
            read -p "请输入要开放的端口 (如 8080,3389, 输入q退出): " port
            if [[ $port == "q" ]]; then
                break
            elif [[ $port =~ ^[0-9]+$ ]]; then
                ufw allow $port/tcp
                log_info "已开放端口: $port"
            else
                log_warn "端口号无效: $port"
            fi
        done

    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL使用firewalld
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        log_info "防火墙已启用，SSH端口已开放"

        read -p "是否要开放其他端口用于内网穿透? (y/n): " open_more_ports
        while [[ $open_more_ports == "y" ]]; do
            read -p "请输入要开放的端口 (如 8080,3389, 输入q退出): " port
            if [[ $port == "q" ]]; then
                break
            elif [[ $port =~ ^[0-9]+$ ]]; then
                firewall-cmd --permanent --add-port=$port/tcp
                firewall-cmd --reload
                log_info "已开放端口: $port"
            else
                log_warn "端口号无效: $port"
            fi
        done
    else
        log_warn "未检测到防火墙工具，请手动配置防火墙"
    fi
}

# 创建管理用户
create_tunnel_user() {
    log_step "创建隧道管理用户..."

    read -p "是否创建专用的内网穿透用户? (y/n, 默认为y): " create_user
    if [[ $create_user != "n" ]]; then
        read -p "请输入用户名 (默认为 tunnel): " username
        username=${username:-tunnel}

        if id "$username" &>/dev/null; then
            log_warn "用户 $username 已存在"
        else
            useradd -m -s /bin/bash "$username"
            echo "用户 $username 创建成功"

            # 设置密码
            read -p "是否设置密码? (y/n): " set_password
            if [[ $set_password == "y" ]]; then
                passwd "$username"
            fi

            # 创建.ssh目录
            mkdir -p /home/$username/.ssh
            chmod 700 /home/$username/.ssh

            log_info "请将客户端的公钥复制到 /home/$username/.ssh/authorized_keys"
            log_info "命令示例: ssh-copy-id -i ~/.ssh/id_rsa.pub $username@$(hostname -I | awk '{print $1}')"
        fi
    fi
}

# 生成客户端配置示例
generate_client_config() {
    log_step "生成客户端配置示例..."

    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    cat > ~/client-config-example.txt << EOF
# ==========================================
# 客户端配置示例
# ==========================================
# 1. 在客户端生成SSH密钥:
#    ssh-keygen -t rsa -b 2048
#
# 2. 复制公钥到服务器:
#    ssh-copy-id -i ~/.ssh/id_rsa.pub ${username:-root}@$VPS_IP
#
# 3. 常用隧道命令:
#    # 反向隧道 (将内网服务暴露到公网)
#    ssh -NR 8080:localhost:80 ${username:-root}@$VPS_IP
#    # 访问: http://$VPS_IP:8080
#
#    # 本地隧道 (通过VPS访问内网服务)
#    ssh -NL 3389:内网IP:3389 ${username:-root}@$VPS_IP
#
#    # 保持连接
#    autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \\
#      -NR 2222:localhost:22 ${username:-root}@$VPS_IP
#
# 4. 更多用法参考文档
EOF

    log_info "客户端配置示例已保存到: ~/client-config-example.txt"
}

# 显示配置摘要
show_summary() {
    log_step "配置完成摘要"
    echo "=========================================="
    echo "服务端IP: $(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
    echo "SSH端口: $(grep -i '^Port' /etc/ssh/sshd_config | awk '{print $2}' || echo '22')"
    echo "已开放端口: $(sudo ufw status 2>/dev/null | grep ALLOW | awk '{print $1}' | tr '\n' ',' || sudo firewall-cmd --list-ports 2>/dev/null || echo '请检查防火墙配置')"
    echo "隧道用户: ${username:-root}"
    echo "=========================================="
    log_info "服务端配置完成!"
}

# 主函数
main() {
    print_banner
    check_root

    log_info "开始配置SSH内网穿透服务端..."

    install_dependencies
    configure_ssh
    configure_firewall
    create_tunnel_user
    generate_client_config
    show_summary

    log_info "请确保客户端可以通过SSH密钥连接到本服务器"
}

# 执行主函数
main "$@"
