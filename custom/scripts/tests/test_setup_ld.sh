#!/usr/bin/env bash
#===========================================================
# 脚本名称: test_setup_ld.sh
# 功能: setup_ld.sh 行为测试（不触碰真实 ~/.bashrc）
# 用法: ./test_setup_ld.sh
#===========================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup_ld.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
check() {
    local desc="$1"
    shift
    if "$@"; then
        PASS=$((PASS + 1))
        printf '✔ %s\n' "$desc"
    else
        FAIL=$((FAIL + 1))
        printf '✘ %s\n' "$desc"
    fi
}

# 1. 语法与 -h
check "bash 语法检查" bash -n "$SETUP"
check "-h 退出码 0" bash "$SETUP" -h

# 2. 首次写入（--file + --dir + --yes）
RC="$TMP/rc_test"
bash "$SETUP" --file "$RC" --dir /opt/test --yes >/dev/null
check "rc 文件已创建" test -f "$RC"
check "含 LARADOCK_DIR" grep -q 'LARADOCK_DIR="/opt/test"' "$RC"
check "含 ld()" grep -q '^ld()' "$RC"
check "含 alias" grep -q "alias laradock='ld'" "$RC"
check "含补全" grep -q "complete -F _ld_complete ld" "$RC"
check "含结束标记" grep -q '# ── Laradock 全局命令结束 ──' "$RC"

# 3. 幂等：再次运行不追加
N1=$(wc -l < "$RC")
bash "$SETUP" --file "$RC" --dir /opt/test --yes >/dev/null
N2=$(wc -l < "$RC")
check "幂等不重复追加" test "$N1" = "$N2"

# 4. 手抄版备份替换
RC2="$TMP/rc_manual"
printf 'ld() { echo manual; }\n' > "$RC2"
bash "$SETUP" --file "$RC2" --dir /opt/test --yes >/dev/null
BAK=$(find "$TMP" -maxdepth 1 -name 'rc_manual.bak.*')
check "手抄版触发备份" test -n "$BAK"
check "手抄版被替换" grep -q "alias laradock='ld'" "$RC2"

# 5. dry-run 不写
RC3="$TMP/rc_dry"
bash "$SETUP" --file "$RC3" --dir /opt/test --dry-run >/dev/null
check "dry-run 不写文件" test ! -f "$RC3"

# 6. zsh：SHELL 检测写 ~/.zshrc 且含 bashcompinit
mkdir -p "$TMP/home"
HOME="$TMP/home" SHELL=/usr/bin/zsh bash "$SETUP" --dir /opt/test --yes >/dev/null
check "zsh 写 .zshrc" test -f "$TMP/home/.zshrc"
check "zsh 含 bashcompinit" grep -q 'autoload -Uz bashcompinit' "$TMP/home/.zshrc"

# 7. bash 默认 SHELL 检测
mkdir -p "$TMP/home2"
HOME="$TMP/home2" SHELL=/bin/bash bash "$SETUP" --dir /opt/test --yes >/dev/null
check "bash 写 .bashrc" test -f "$TMP/home2/.bashrc"
check "bash 不含 bashcompinit" bash -c "! grep -q 'bashcompinit' \"$TMP/home2/.bashrc\""

# 8. 真实 source 验证：写入的配置块 source 后函数与 alias 可用
check "source 后 ld 函数可用" bash -c "source '$RC' && type ld >/dev/null 2>&1"
check "source 后 alias 可用" bash -c "source '$RC' && alias laradock >/dev/null 2>&1"
check "source 后补全函数可用" bash -c "source '$RC' && type _ld_complete >/dev/null 2>&1"

echo "-------------------"
echo "结果: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
