#!/usr/bin/env bash
#===========================================================
# 脚本名称: setup_ld.sh
# 功能: 宿主机一键配置 Laradock 全局命令（ldk / alias / tab 补全）
# 用法:
#   ./setup_ld.sh [--file <rc文件>] [--dir <laradock路径>] [--yes] [--dry-run] [-h]
#   source setup_ld.sh --yes     # 写入后把 ldk 注入当前 shell，立即生效
#   --file <rc>    指定目标 rc 文件（跳过 shell 检测）
#   --dir <路径>   指定 LARADOCK_DIR（跳过 git 推导）
#   --yes          跳过确认直接写入
#   --dry-run      只预览，不实际修改
#   -h, --help     显示本帮助
#===========================================================

# 被 source 调用时不得启用 set -euo（会污染调用者 shell 选项），
# 且所有退出用 return 而非 exit（exit 会退出调用者的 shell）。
SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    SOURCED=1
else
    set -euo pipefail
fi
SCRIPT_PATH="${BASH_SOURCE[0]}"

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
用法: $SCRIPT_PATH [--file <rc文件>] [--dir <laradock路径>] [--yes] [--dry-run] [-h]
  --file <rc>    指定目标 rc 文件（跳过 shell 检测）
  --dir <路径>   指定 LARADOCK_DIR（跳过 git 推导）
  --yes          跳过确认直接写入
  --dry-run      只预览，不实际修改
  -h, --help     显示本帮助
EOF
}

# ---------- 目标 rc 文件检测 ----------
# IS_ZSH=1 时补全需加 bashcompinit（zsh 兼容 bash 补全语法）
IS_ZSH=0
detect_rc_file() {
    local shell_base
    if [[ -n "$FILE_ARG" ]]; then
        # 文件名含 zsh 视为 zsh 目标（如 --file ~/.zshrc）；IS_ZSH 由 main 从 rc 路径反推
        echo "$FILE_ARG"
        return 0
    fi
    shell_base="${SHELL##*/}"
    case "$shell_base" in
        bash)
            echo "$HOME/.bashrc"
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        *)
            echo -e "${RED}错误: 无法从 SHELL=$SHELL 判断 rc 文件${NC}" >&2
            echo -e "${YELLOW}提示: 请用 --file <rc文件> 显式指定${NC}" >&2
            return 1
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
        return 1
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
ldk() {
  ( cd "\$LARADOCK_DIR" && ./laradock "\$@" )
}
alias laradock='ldk'
_ldk_complete() {
  local cmds=(setup start stop restart logs info doctor workspace enter db set settings unset edit ship test open share remove rebuild)
  COMPREPLY=( \$(compgen -W "\${cmds[*]}" -- "\${COMP_WORDS[COMP_CWORD]}") )
}
${compinit_line}
complete -F _ldk_complete ldk
# ── Laradock 全局命令结束 ──
EOF
}

# ---------- 幂等 / 备份检测 ----------
END_MARK='# ── Laradock 全局命令结束 ──'

is_installed() {
    [[ -f "$1" ]] && grep -qF "$END_MARK" "$1"
}

# 检测到无标记的手抄版 ldk() / alias 时才需要备份
has_manual_version() {
    [[ -f "$1" ]] && grep -qE '^[[:space:]]*ldk\(\)|^[[:space:]]*alias[[:space:]]+laradock=' "$1"
}

backup_rc() {
    local bak="${1}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$1" "$bak"
    echo "$bak"
}

# 从 rc 提取配置块并 source（注入当前 shell）。直接运行时仅自检；被 source 时真正生效。
source_block_from_rc() {
    local rc="$1"
    local tmp_block
    tmp_block="$(mktemp)"
    # 提取开始标记到结束标记之间的内容
    sed -n '/# ── Laradock 全局命令：任意目录可用 ──/,/# ── Laradock 全局命令结束 ──/p' "$rc" > "$tmp_block" 2>/dev/null
    if [[ -s "$tmp_block" ]] && source "$tmp_block" 2>/dev/null; then
        rm -f "$tmp_block"
        echo -e "${GREEN}✔ 已自动 source 配置块，ldk 立即可用${NC}"
        return 0
    fi
    rm -f "$tmp_block"
    echo -e "${YELLOW}⚠ 自动 source 配置块失败，请手动: source $rc${NC}"
    return 1
}

main() {
    local rc dir block ans tmp_block

    # ---------- 参数解析 ----------
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}错误: --file 需要一个参数${NC}"
                    usage
                    return 1
                fi
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo -e "${RED}错误: --file 需要非空参数${NC}"
                    usage
                    return 1
                fi
                FILE_ARG="$2"
                shift 2
                ;;
            --dir)
                if [[ $# -lt 2 ]]; then
                    echo -e "${RED}错误: --dir 需要一个参数${NC}"
                    usage
                    return 1
                fi
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo -e "${RED}错误: --dir 需要非空参数${NC}"
                    usage
                    return 1
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
                return 0
                ;;
            *)
                echo -e "${RED}错误: 无法识别的参数 '$1'${NC}"
                usage
                return 1
                ;;
        esac
    done

    # ---------- 检测 ----------
    if ! rc="$(detect_rc_file)"; then
        return 1
    fi
    # 命令替换使 detect_rc_file 在子 shell 运行，其内赋值不传播；
    # 由 rc 路径反推 zsh 标记（文件名含 zsh 视为 zsh 目标）
    case "$rc" in
        *zsh*) IS_ZSH=1 ;;
        *)     IS_ZSH=0 ;;
    esac
    if ! dir="$(detect_laradock_dir)"; then
        return 1
    fi
    block="$(build_block "$dir")"

    # ---------- 幂等 ----------
    if is_installed "$rc"; then
        if [[ "$SOURCED" == "1" ]]; then
            # 被 source 调用：提取已写入的配置块注入当前 shell，立即生效
            echo -e "${CYAN}$rc 已配置，为当前终端加载配置块...${NC}"
            source_block_from_rc "$rc"
        else
            echo -e "${GREEN}✔ $rc 已配置 Laradock 全局命令，无需重复安装${NC}"
        fi
        return 0
    fi

    # ---------- 预览 ----------
    echo -e "${CYAN}将要写入: $rc${NC}"
    echo -e "${CYAN}LARADOCK_DIR: $dir${NC}"
    echo -e "${YELLOW}--- 配置块预览 ---${NC}"
    echo "$block"
    echo -e "${YELLOW}--------------------${NC}"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${YELLOW}[dry-run] 未写入任何文件${NC}"
        return 0
    fi

    # ---------- 确认（--yes 跳过） ----------
    if [[ "$YES" == "0" ]]; then
        read -r -p "确认写入？[Y/n] " ans
        if [[ "$ans" =~ ^[Nn] ]]; then
            echo -e "${YELLOW}已取消${NC}"
            return 0
        fi
    fi

    # ---------- 备份手抄版（若存在） ----------
    if has_manual_version "$rc"; then
        local bak
        bak="$(backup_rc "$rc")"
        echo -e "${YELLOW}检测到已有的手抄版配置，已备份到 $bak${NC}"
    fi

    # ---------- 写入 ----------
    mkdir -p "$(dirname "$rc")"
    printf '%s\n' "$block" >> "$rc"
    echo -e "${GREEN}✔ 已写入 $rc${NC}"

    # 立即生效：只 source 配置块本身（不 source 整个 rc，避免 rc 内未设变量
    # / tput / exit 等在交互与非交互环境下的副作用）。被 source 调用时注入调用者 shell。
    tmp_block="$(mktemp)"
    printf '%s\n' "$block" > "$tmp_block"
    if source "$tmp_block" 2>/dev/null; then
        rm -f "$tmp_block"
        echo -e "${GREEN}✔ 已自动 source 配置块，ldk 立即可用${NC}"
    else
        rm -f "$tmp_block"
        echo -e "${YELLOW}⚠ 自动 source 配置块失败，请手动: source $rc${NC}"
    fi
    echo -e "${CYAN}当前终端立即可用: source $SCRIPT_PATH --yes${NC}"
    echo -e "${CYAN}验证: cd /tmp && ldk version; ldk doctor${NC}"
    return 0
}

main "$@"
