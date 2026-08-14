#!/usr/bin/env bash
#===========================================================
# 脚本名称: setup_ld.sh
# 功能: 宿主机一键配置 Laradock 全局命令（ld / alias / tab 补全）
# 用法: ./setup_ld.sh [--file <rc文件>] [--dir <laradock路径>] [--yes] [--dry-run] [-h]
#   --file <rc>    指定目标 rc 文件（跳过 shell 检测）
#   --dir <路径>   指定 LARADOCK_DIR（跳过 git 推导）
#   --yes          跳过确认直接写入
#   --dry-run      只预览，不实际修改
#   -h, --help     显示本帮助
#===========================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- 参数 ----------
FILE_ARG=""
DIR_ARG=""
YES=0
DRY_RUN=0

usage() {
    cat <<EOF
用法: $0 [--file <rc文件>] [--dir <laradock路径>] [--yes] [--dry-run] [-h]
  --file <rc>    指定目标 rc 文件（跳过 shell 检测）
  --dir <路径>   指定 LARADOCK_DIR（跳过 git 推导）
  --yes          跳过确认直接写入
  --dry-run      只预览，不实际修改
  -h, --help     显示本帮助
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}错误: --file 需要一个参数${NC}"
                usage
                exit 1
            fi
            FILE_ARG="$2"
            shift 2
            ;;
        --dir)
            if [[ $# -lt 2 ]]; then
                echo -e "${RED}错误: --dir 需要一个参数${NC}"
                usage
                exit 1
            fi
            DIR_ARG="$2"
            shift 2
            ;;
        --yes)
            YES=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 无法识别的参数 '$1'${NC}"
            usage
            exit 1
            ;;
    esac
done

# ---------- 目标 rc 文件检测 ----------
# IS_ZSH=1 时补全需加 bashcompinit（zsh 兼容 bash 补全语法）
IS_ZSH=0
detect_rc_file() {
    local shell_base
    if [[ -n "$FILE_ARG" ]]; then
        # 文件名含 zsh 视为 zsh 目标（如 --file ~/.zshrc）
        if [[ "$FILE_ARG" == *zsh* ]]; then
            IS_ZSH=1
        else
            IS_ZSH=0
        fi
        echo "$FILE_ARG"
        return 0
    fi
    shell_base="${SHELL##*/}"
    case "$shell_base" in
        bash)
            IS_ZSH=0
            echo "$HOME/.bashrc"
            ;;
        zsh)
            IS_ZSH=1
            echo "$HOME/.zshrc"
            ;;
        *)
            echo -e "${RED}错误: 无法从 SHELL=$SHELL 判断 rc 文件${NC}" >&2
            echo -e "${YELLOW}提示: 请用 --file <rc文件> 显式指定${NC}" >&2
            exit 1
            ;;
    esac
}

# ---------- LARADOCK_DIR 推导 ----------
detect_laradock_dir() {
    local script_dir repo_root
    if [[ -n "$DIR_ARG" ]]; then
        echo "$DIR_ARG"
        return 0
    fi
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if ! repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        echo -e "${RED}错误: 无法自动推导 LARADOCK_DIR${NC}" >&2
        echo -e "${YELLOW}提示: 请用 --dir <路径> 显式指定${NC}" >&2
        exit 1
    fi
    echo "$repo_root"
}

# ---------- 配置块构建 ----------
# 注意: heredoc 内 \$ 保留为字面量（写入 rc 后运行时才展开）
build_block() {
    local dir="$1"
    local compinit_line=""
    [[ "$IS_ZSH" == "1" ]] && compinit_line="autoload -Uz bashcompinit && bashcompinit"
    cat <<EOF

# ── Laradock 全局命令：任意目录可用 ──
LARADOCK_DIR="$dir"
ld() {
  ( cd "\$LARADOCK_DIR" && ./laradock "\$@" )
}
alias laradock='ld'
_ld_complete() {
  local cmds=(setup start stop restart logs info doctor workspace enter db set settings unset edit ship test open share remove rebuild)
  COMPREPLY=( \$(compgen -W "\${cmds[*]}" -- "\${COMP_WORDS[COMP_CWORD]}") )
}
${compinit_line}
complete -F _ld_complete ld
# ── Laradock 全局命令结束 ──
EOF
}

# ---------- 幂等 / 备份检测 ----------
END_MARK='# ── Laradock 全局命令结束 ──'

is_installed() {
    [[ -f "$1" ]] && grep -qF "$END_MARK" "$1"
}

# 检测到无标记的手抄版 ld() / alias 时才需要备份
has_manual_version() {
    [[ -f "$1" ]] && grep -qE '^[[:space:]]*ld\(\)|^[[:space:]]*alias[[:space:]]+laradock=' "$1"
}

backup_rc() {
    local bak="${1}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$1" "$bak"
    echo "$bak"
}

main() {
    local rc dir block ans
    rc="$(detect_rc_file)"
    # 命令替换使 detect_rc_file 在子 shell 运行，其内 IS_ZSH 赋值不传播；
    # 由 rc 路径反推 zsh 标记（文件名含 zsh 视为 zsh 目标）
    case "$rc" in
        *zsh*) IS_ZSH=1 ;;
        *)     IS_ZSH=0 ;;
    esac
    dir="$(detect_laradock_dir)"
    block="$(build_block "$dir")"

    # 幂等：已配置则直接退出
    if is_installed "$rc"; then
        echo -e "${GREEN}✔ $rc 已配置 Laradock 全局命令，无需重复安装${NC}"
        exit 0
    fi

    # 预览
    echo -e "${CYAN}将要写入: $rc${NC}"
    echo -e "${CYAN}LARADOCK_DIR: $dir${NC}"
    echo -e "${YELLOW}--- 配置块预览 ---${NC}"
    echo "$block"
    echo -e "${YELLOW}--------------------${NC}"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${YELLOW}[dry-run] 未写入任何文件${NC}"
        exit 0
    fi

    # 确认（--yes 跳过）
    if [[ "$YES" == "0" ]]; then
        read -r -p "确认写入？[Y/n] " ans
        if [[ "$ans" =~ ^[Nn] ]]; then
            echo -e "${YELLOW}已取消${NC}"
            exit 0
        fi
    fi

    # 备份手抄版（若存在）
    if has_manual_version "$rc"; then
        local bak
        bak="$(backup_rc "$rc")"
        echo -e "${YELLOW}检测到已有的手抄版配置，已备份到 $bak${NC}"
    fi

    # 写入
    mkdir -p "$(dirname "$rc")"
    printf '%s\n' "$block" >> "$rc"
    echo -e "${GREEN}✔ 已写入 $rc${NC}"
    echo -e "${CYAN}生效: source $rc${NC}"
    echo -e "${CYAN}验证: cd /tmp && ld version; ld doctor${NC}"
}

main "$@"
