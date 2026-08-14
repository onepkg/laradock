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

echo -e "${CYAN}参数解析完成: FILE='$FILE_ARG' DIR='$DIR_ARG' YES=$YES DRY=$DRY_RUN${NC}"
