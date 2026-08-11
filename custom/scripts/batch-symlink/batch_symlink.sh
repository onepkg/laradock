#!/usr/bin/env bash
#===========================================================
# 脚本名称: batch_symlink.sh
# 功能: 根据映射文件批量创建符号链接
# 用法: ./batch_symlink.sh 映射文件 [--force] [--dry-run]
#   --force    覆盖已存在的目标文件（自动备份为 .bak）
#   --dry-run  仅预览，不实际执行
#===========================================================

set -euo pipefail

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- 参数解析 ----------
FORCE=0
DRY_RUN=0
MAP_FILE=""

usage() {
    echo "用法: $0 <映射文件> [--force] [--dry-run]"
    echo "映射文件格式: 源路径 目标路径  (每行一对, 用空格或Tab分隔)"
    echo "  --force      强制覆盖目标文件（原文件备份为 .bak）"
    echo "  --dry-run    只显示将要执行的操作，不实际修改"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            if [ -z "$MAP_FILE" ]; then
                MAP_FILE="$1"
                shift
            else
                echo -e "${RED}错误: 无法识别的参数 '$1'${NC}"
                usage
            fi
            ;;
    esac
done

if [ -z "$MAP_FILE" ]; then
    echo -e "${RED}错误: 必须指定映射文件${NC}"
    usage
fi

if [ ! -f "$MAP_FILE" ]; then
    echo -e "${RED}错误: 映射文件 '$MAP_FILE' 不存在${NC}"
    exit 1
fi

# ---------- 处理核心 ----------
process_link() {
    local src="$1"
    local dest="$2"

    # 检查源是否存在
    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        echo -e "${RED}[错误] 源路径不存在: $src${NC}"
        return 1
    fi

    # 如果目标已是正确软链接
    if [ -L "$dest" ]; then
        local current_src
        current_src=$(readlink "$dest")
        if [ "$current_src" = "$src" ]; then
            echo -e "${GREEN}[跳过] 已是正确链接: $dest -> $src${NC}"
            return 0
        fi
    fi

    # 如果目标存在且不是我们要的链接
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$FORCE" -eq 0 ]; then
            echo -e "${YELLOW}[警告] 目标已存在且不是期望链接，跳过 (使用 --force 覆盖): $dest${NC}"
            return 1
        else
            # 备份
            local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
            if [ "$DRY_RUN" -eq 1 ]; then
                echo -e "${CYAN}[DRY-RUN] 将备份: $dest -> $backup${NC}"
            else
                mv "$dest" "$backup"
                echo -e "${YELLOW}[备份] 原目标已备份至: $backup${NC}"
            fi
        fi
    fi

    # 创建父目录
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo -e "${CYAN}[DRY-RUN] 将创建目录: $dest_dir${NC}"
        else
            mkdir -p "$dest_dir"
            echo -e "${GREEN}[创建目录] $dest_dir${NC}"
        fi
    fi

    # 创建软链接
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "${CYAN}[DRY-RUN] 将创建软链接: $dest -> $src${NC}"
    else
        ln -s "$src" "$dest"
        echo -e "${GREEN}[成功] 创建软链接: $dest -> $src${NC}"
    fi
}

# ---------- 主循环 ----------
ERROR_COUNT=0
LINE_NUM=0

echo -e "======================================"
echo -e "批量符号链接操作"
echo -e "映射文件: $MAP_FILE"
[ "$DRY_RUN" -eq 1 ] && echo -e "模式: ${CYAN}预览模式 (不会实际修改)${NC}"
[ "$FORCE"  -eq 1 ] && echo -e "选项: ${YELLOW}强制覆盖模式已开启${NC}"
echo -e "======================================"

while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))
    # 去除首尾空白
    line=$(echo "$line" | xargs)
    # 跳过空行和注释
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    # 分割字段
    src=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $2}')

    if [ -z "$src" ] || [ -z "$dest" ]; then
        echo -e "${RED}[格式错误] 第${LINE_NUM}行: 源或目标为空${NC}"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        continue
    fi

    process_link "$src" "$dest" || ERROR_COUNT=$((ERROR_COUNT + 1))
done < "$MAP_FILE"

echo -e "======================================"
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${CYAN}预览完成。要实际执行，请去掉 --dry-run 参数。${NC}"
fi
if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${YELLOW}共遇到 ${ERROR_COUNT} 个问题，请检查上方输出。${NC}"
else
    echo -e "${GREEN}所有软链接处理完毕，一切正常。${NC}"
fi
