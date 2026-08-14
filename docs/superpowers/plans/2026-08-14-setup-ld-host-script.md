# setup_ld.sh 宿主机一键配置脚本 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提供一个宿主机一键脚本，自动把 `LARADOCK_DIR + ld() + alias + tab 补全` 配置块写入 `~/.bashrc`（zsh 则 `~/.zshrc`），并更新 README 说明。

**Architecture:** 单个 bash 脚本 `custom/scripts/setup_ld.sh`（仿既有 `batch_symlink.sh` 风格）+ 一个行为测试脚本。脚本内部按「参数解析 → 目标 rc 检测 → LARADOCK_DIR 推导 → 幂等检查 → 备份 → 确认 → 写入」流水线组织，配置块以 `# ── Laradock 全局命令结束 ──` 标记边界，支持幂等与备份替换。

**Tech Stack:** 纯 bash（5.2+），无外部依赖；测试用 bash 断言脚本。

## Global Constraints

- 脚本路径固定为 `custom/scripts/setup_ld.sh`，须 `chmod +x`。
- 风格仿 `custom/scripts/batch-symlink/batch_symlink.sh`：`set -euo pipefail`、颜色常量（RED/GREEN/YELLOW/CYAN/NC）、`usage()`、while-case 参数解析、中文注释、中文消息。
- 配置块尾部标记必须是精确字符串 `# ── Laradock 全局命令结束 ──`（幂等识别的唯一依据）。
- zsh 目标（`$SHELL` 含 zsh 或 `--file` 路径含 `zsh`）时，补全前插入 `autoload -Uz bashcompinit && bashcompinit`；bash 目标不插入。
- 不改动任何上游文件；只新增脚本、测试、README 修改。
- 默认 shell 检测优先级：`--file` > `$SHELL` 末尾匹配（bash→`~/.bashrc`，zsh→`~/.zshrc`）> 报错提示。
- `LARADOCK_DIR` 优先级：`--dir` > `git -C "$(脚本目录)" rev-parse --show-toplevel` > 报错提示。
- commit message 用中文 Conventional Commits，结尾带 `Co-Authored-By: Claude <noreply@anthropic.com>`。

---

### Task 1: 脚本骨架与参数解析

**Files:**
- Create: `custom/scripts/setup_ld.sh`

**Interfaces:**
- Produces: `setup_ld.sh` 可运行，`-h/--help` 退出码 0；未知参数退出码 1。`FILE_ARG` / `DIR_ARG` / `YES` / `DRY_RUN` 四个全局变量由参数解析填充（Task 2、3 消费）。

- [ ] **Step 1: 创建脚本（骨架 + 颜色 + usage + 参数解析）**

写入 `custom/scripts/setup_ld.sh`：

```bash
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
```

- [ ] **Step 2: 设置可执行位并验证参数解析**

```bash
chmod +x custom/scripts/setup_ld.sh
bash -n custom/scripts/setup_ld.sh
bash custom/scripts/setup_ld.sh -h            # 期望: 打印用法，退出码 0
bash custom/scripts/setup_ld.sh --bad; echo $? # 期望: 报"无法识别的参数"，退出码 1
bash custom/scripts/setup_ld.sh --file ~/x --dir /y --yes --dry-run
# 期望: 打印 参数解析完成: FILE='/root/x' DIR='/y' YES=1 DRY=1
```

- [ ] **Step 3: Commit**

```bash
git add custom/scripts/setup_ld.sh
git commit -m "feat(custom): 新增宿主机 setup_ld.sh 一键配置脚本（骨架与参数解析）

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: 目标 rc 检测与 LARADOCK_DIR 推导

**Files:**
- Modify: `custom/scripts/setup_ld.sh`（把末尾的 `echo "参数解析完成…"` 替换为检测函数 + main）

**Interfaces:**
- Consumes: `FILE_ARG` / `DIR_ARG` / `SHELL`（Task 1 或环境）。
- Produces: `detect_rc_file()`（echo 目标 rc 路径；设置全局 `IS_ZSH`，0=bash 1=zsh）、`detect_laradock_dir()`（echo 仓库根或 `--dir` 值）、`main()` 入口。

- [ ] **Step 1: 追加检测函数并重写 main**

把 Task 1 末尾的 `echo -e "${CYAN}参数解析完成…"` 整行删除，替换为：

```bash
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

main() {
    local rc dir
    rc="$(detect_rc_file)"
    # 命令替换使 detect_rc_file 在子 shell 运行，其内 IS_ZSH 赋值不传播；
    # 由 rc 路径反推 zsh 标记（文件名含 zsh 视为 zsh 目标）
    case "$rc" in
        *zsh*) IS_ZSH=1 ;;
        *)     IS_ZSH=0 ;;
    esac
    dir="$(detect_laradock_dir)"
    echo -e "${CYAN}目标文件: $rc${NC}"
    echo -e "${CYAN}LARADOCK_DIR: $dir${NC}"
    echo -e "${CYAN}IS_ZSH: $IS_ZSH${NC}"
}

main "$@"
```

- [ ] **Step 2: 验证检测逻辑**

```bash
bash -n custom/scripts/setup_ld.sh
# 1) git 推导（本机 SHELL=/bin/bash）
bash custom/scripts/setup_ld.sh
# 期望: 目标文件: /root/.bashrc  LARADOCK_DIR: /var/www/github.com/onepkg/laradock  IS_ZSH: 0
# 2) --dir 覆盖
bash custom/scripts/setup_ld.sh --dir /opt/other
# 期望: LARADOCK_DIR: /opt/other
# 3) --file 覆盖（含 zsh 判定）
bash custom/scripts/setup_ld.sh --file /tmp/rc_zsh
# 期望: 目标文件: /tmp/rc_zsh  IS_ZSH: 1
bash custom/scripts/setup_ld.sh --file /tmp/rc_bash
# 期望: 目标文件: /tmp/rc_bash  IS_ZSH: 0
# 4) SHELL 无法判断时
SHELL=/bin/sh bash custom/scripts/setup_ld.sh; echo $?
# 期望: 报"无法从 SHELL 判断 rc 文件"，退出码 1
```

- [ ] **Step 3: Commit**

```bash
git add custom/scripts/setup_ld.sh
git commit -m "feat(custom): setup_ld.sh 支持 rc 文件检测与 LARADOCK_DIR 自动推导

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: 配置块构建与幂等写入

**Files:**
- Modify: `custom/scripts/setup_ld.sh`（把 main 中的调试 echo 替换为完整写入逻辑；追加 build_block / is_installed / has_manual_version / backup_rc）

**Interfaces:**
- Consumes: `IS_ZSH`（Task 2）、`detect_rc_file()`、`detect_laradock_dir()`。
- Produces: 写入目标 rc 的配置块，含尾部标记 `# ── Laradock 全局命令结束 ──`；幂等检测函数 `is_installed <rc>`；备份 `backup_rc <rc>`（echo 备份路径）。

- [ ] **Step 1: 追加构建/检测/备份函数，重写 main**

在 `detect_laradock_dir` 函数之后、`main()` 之前插入：

```bash
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
```

将现有 `main()` 整体替换为：

```bash
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
```

- [ ] **Step 2: 验证核心行为（全部用临时文件，不碰真实 ~/.bashrc）**

```bash
bash -n custom/scripts/setup_ld.sh
T=$(mktemp -d)

# 首次写入
bash custom/scripts/setup_ld.sh --file "$T/rc1" --dir /opt/test --yes
# 期望: 输出 已写入 $T/rc1
grep -c 'LARADOCK_DIR="/opt/test"' "$T/rc1"           # 1
grep -c '^ld()' "$T/rc1"                              # 1
grep -c "alias laradock='ld'" "$T/rc1"                # 1
grep -c 'complete -F _ld_complete ld' "$T/rc1"        # 1
grep -c 'bashcompinit' "$T/rc1"                       # 0（bash 目标）

# 幂等：再次运行不追加
N1=$(wc -l < "$T/rc1")
bash custom/scripts/setup_ld.sh --file "$T/rc1" --dir /opt/test --yes >/dev/null
N2=$(wc -l < "$T/rc1")
test "$N1" = "$N2" && echo "幂等 OK"                  # 幂等 OK

# 手抄版备份替换
printf 'ld() { echo manual; }\n' > "$T/rc2"
bash custom/scripts/setup_ld.sh --file "$T/rc2" --dir /opt/test --yes >/dev/null
ls "$T"/rc2.bak.* >/dev/null && echo "备份 OK"        # 备份 OK
grep -q "alias laradock='ld'" "$T/rc2" && echo "替换 OK"

# dry-run 不写
bash custom/scripts/setup_ld.sh --file "$T/rc3" --dir /opt/test --dry-run >/dev/null
test ! -f "$T/rc3" && echo "dry-run OK"               # dry-run OK

# zsh 分支（SHELL 覆盖检测 ~/.zshrc）
mkdir -p "$T/home"
HOME="$T/home" SHELL=/usr/bin/zsh bash custom/scripts/setup_ld.sh --dir /opt/test --yes >/dev/null
grep -q 'autoload -Uz bashcompinit' "$T/home/.zshrc" && echo "zsh compinit OK"

# 确认取消（输入 n）
printf 'n\n' | bash custom/scripts/setup_ld.sh --file "$T/rc4" --dir /opt/test
test ! -f "$T/rc4" && echo "取消 OK"                  # 取消 OK

rm -rf "$T"
```

- [ ] **Step 3: Commit**

```bash
git add custom/scripts/setup_ld.sh
git commit -m "feat(custom): setup_ld.sh 完成配置块构建与幂等写入

自动检测已配置、备份替换手抄版、zsh 自动加 bashcompinit。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: 行为测试脚本

**Files:**
- Create: `custom/scripts/tests/test_setup_ld.sh`

**Interfaces:**
- Consumes: `custom/scripts/setup_ld.sh`（Task 1-3 产物）。
- Produces: 可重复运行的断言脚本；退出码 0 = 全过，非 0 = 有失败。

- [ ] **Step 1: 创建测试脚本**

写入 `custom/scripts/tests/test_setup_ld.sh`：

```bash
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
#    （reviewer 补充：验证运行时真实行为，非仅 grep 存在性）
check "source 后 ld 函数可用" bash -c "source '$RC' && type ld >/dev/null 2>&1"
check "source 后 alias 可用" bash -c "source '$RC' && alias laradock >/dev/null 2>&1"
check "source 后补全函数可用" bash -c "source '$RC' && type _ld_complete >/dev/null 2>&1"

echo "-------------------"
echo "结果: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 2: 运行测试，全绿**

```bash
chmod +x custom/scripts/tests/test_setup_ld.sh
bash custom/scripts/tests/test_setup_ld.sh
# 期望: 每个 check 都输出 ✔，结尾 结果: PASS=19 FAIL=0
```

（若某一项失败，按 systematic-debugging 排查 setup_ld.sh 对应函数后重跑。）

- [ ] **Step 3: Commit**

```bash
git add custom/scripts/tests/test_setup_ld.sh
git commit -m "test(custom): 新增 setup_ld.sh 行为测试

覆盖首次写入、幂等、备份替换、dry-run、zsh/bash 检测。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: README 更新与最终验证

**Files:**
- Modify: `custom/README.md:93-147`（宿主机章节 + tab 补全小节；容器内、多套环境切换等其余不动）

**Interfaces:**
- Consumes: `setup_ld.sh` 的最终用法（`--file` / `--dir` / `--yes` / `--dry-run`）。

- [ ] **Step 1: 重写宿主机章节**

把 `custom/README.md` 中「### 宿主机（WSL / macOS / Linux）」一节（含其下的代码块、生效并测试段）与「### 可选：tab 补全」一节整体替换为：

````markdown
### 宿主机（WSL / macOS / Linux）

推荐一键配置（自动检测 bash/zsh、自动推导路径、幂等 + 备份替换手抄版）：

```bash
custom/scripts/setup_ld.sh            # 预览并确认后写入（回车默认确认）
custom/scripts/setup_ld.sh --yes      # 跳过确认直接写入
custom/scripts/setup_ld.sh --dry-run  # 只预览不写入
```

| 参数 | 说明 |
|---|---|
| `--file <rc>` | 指定目标 rc 文件（默认按 `$SHELL` 检测 `~/.bashrc` / `~/.zshrc`）|
| `--dir <路径>` | 指定 `LARADOCK_DIR`（默认自动推导仓库根目录）|
| `--yes` | 跳过确认 |
| `--dry-run` | 只预览不写入 |

脚本默认已包含 tab 补全（zsh 自动加 `bashcompinit`）。

生效并测试：

```bash
source ~/.bashrc
cd /tmp && ld version    # → laradock cli 1.0.0
ld doctor                # 任意目录都行
ld workspace             # 进开发容器
```

或手动添加以下内容（脚本写入的等价物）：

```bash
# ── Laradock 全局命令：任意目录可用 ──
LARADOCK_DIR="/var/www/github.com/onepkg/laradock"   # ← 改成你的实际路径
ld() {
  ( cd "$LARADOCK_DIR" && ./laradock "$@" )
}
alias laradock='ld'
```

### 可选：手动 tab 补全

`setup_ld.sh` 默认已包含，无需手动添加；手动方式如下（zsh 需先
`autoload -Uz bashcompinit && bashcompinit`）：

```bash
_ld_complete() {
  local cmds=(setup start stop restart logs info doctor workspace enter db set settings unset edit ship test open share remove rebuild)
  COMPREPLY=( $(compgen -W "${cmds[*]}" -- "${COMP_WORDS[COMP_CWORD]}") )
}
complete -F _ld_complete ld
```
````

- [ ] **Step 2: 全量验证**

```bash
# 行为测试全绿
bash custom/scripts/tests/test_setup_ld.sh
# 期望: 结果: PASS=19 FAIL=0

# 真实场景干跑（不写文件）
bash custom/scripts/setup_ld.sh --dry-run
# 期望: 显示将要写入 /root/.bashrc、LARADOCK_DIR=/var/www/github.com/onepkg/laradock、完整配置块

# 确认真实 ~/.bashrc 是否已含标记（若之前手动配过，脚本会提示已配置）
grep -F '# ── Laradock 全局命令结束 ──' ~/.bashrc || echo "（真实 ~/.bashrc 未配置，可放心执行 ./setup_ld.sh）"
```

- [ ] **Step 3: Commit**

```bash
git add custom/README.md
git commit -m "docs(custom): README 宿主机章节改为一键脚本为主、手动为备选

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review 记录

- **Spec 覆盖**：脚本行为（检测/推导/幂等/备份/确认/写入/zsh）→ Task 1-3；测试 → Task 4；README → Task 5；YAGNI 范围（无卸载/无容器内/无模板）→ 全程未引入。✓
- **占位符扫描**：无 TDD/TBD/TODO；所有代码块为最终内容；验证命令给出期望输出。✓
- **一致性**：`END_MARK`、`# ── Laradock 全局命令结束 ──`、`IS_ZSH`、`FILE_ARG`/`DIR_ARG`/`YES`/`DRY_RUN` 在 Task 1-3 间名称一致；测试脚本断言与 Task 3 验证命令一致（19 项 PASS 数与测试脚本实际 check 数吻合）。✓
