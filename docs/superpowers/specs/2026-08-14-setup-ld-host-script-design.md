# 宿主机 `ld` 一键配置脚本设计（setup_ld.sh）

日期：2026-08-14
状态：已获用户确认

## 背景与目标

custom/README.md 的「全局使用」章节要求用户在宿主机（WSL / macOS / Linux）手动把
`LARADOCK_DIR + ld() + alias + tab 补全` 抄进 `~/.bashrc`（zsh 则 `~/.zshrc`），
还需要手动把 `LARADOCK_DIR` 改成实际路径。本设计提供一键脚本自动化此过程，
保留手动方式作为备选。

已确认的范围（brainstorming 澄清结果）：

- **场景**：仅宿主机配置（含 tab 补全）；**不做**容器内配置、不做卸载功能。
- **Shell**：自动检测 bash / zsh（`$SHELL` 末尾判断），zsh 用 `~/.zshrc`。
- **冲突处理**：幂等 + 备份替换。重复运行不重复追加；已有手抄版 `ld()` 时
  先备份整份 rc 文件再写入。
- **交互**：确认式 + 彩色输出；`--yes` 跳过确认。

## 交付物

1. **脚本**：`custom/scripts/setup_ld.sh`（可执行，与 `batch_symlink.sh` 并列）。
2. **文档**：更新 `custom/README.md` 宿主机章节（一键脚本为主、手动为备选）。

## 脚本行为

```
用法: ./setup_ld.sh [--file <rc文件>] [--dir <laradock路径>] [--yes] [--dry-run] [-h]
```

风格仿 `batch_symlink.sh`：`set -euo pipefail`、颜色常量（RED/GREEN/YELLOW/CYAN/NC）、
usage()、循环参数解析。

### 参数

| 参数 | 作用 |
|---|---|
| `--file <rc>` | 显式指定目标 rc 文件（跳过 shell 检测） |
| `--dir <路径>` | 显式指定 `LARADOCK_DIR`（跳过 git 推导） |
| `--yes` | 跳过确认直接写入 |
| `--dry-run` | 只预览不写入 |
| `-h` / `--help` | 用法说明 |

### 执行流程

1. **检测目标文件**：`--file` 优先 → 否则按 `$SHELL` 末尾判断
   （`*/bash`→`~/.bashrc`，`*/zsh`→`~/.zshrc`）→ 都无法确定则报错并提示用 `--file`。
2. **推导 LARADOCK_DIR**：`--dir` 优先 → 否则
   `git -C "$(脚本所在目录)" rev-parse --show-toplevel` 推导仓库根 → 失败则报错提示 `--dir`。
   注意：脚本真实路径用 `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd` 解析，
   兼容符号链接/相对路径调用。
3. **幂等检查**：grep 配置块尾部标记 `# ── Laradock 全局命令结束 ──`；
   已存在则绿色提示"已配置"退出 0。
4. **备份替换**：目标 rc 存在但无标记、且含手抄版 `ld()` 或 `alias laradock` 时，
   先 `cp` 备份为 `~/.bashrc.bak.<时间戳>`（时间戳用 `date +%Y%m%d%H%M%S`）。
   目标 rc 不存在时直接创建，无需备份。
5. **确认**：展示完整配置块 + 目标文件路径 + `LARADOCK_DIR`，`[Y/n]` 回车默认 Y；
   `--yes` 跳过；`--dry-run` 只展示不写。
6. **写入**：heredoc 追加配置块。
7. **收尾**：彩色输出完成信息 + 提示 `source ~/.bashrc` 生效与验证命令
   （`cd /tmp && ld version`、`ld doctor`）。

### 写入的配置块

```bash
# ── Laradock 全局命令：任意目录可用 ──
LARADOCK_DIR="<推导或指定的路径>"
ld() {
  ( cd "$LARADOCK_DIR" && ./laradock "$@" )
}
alias laradock='ld'
_ld_complete() {
  local cmds=(setup start stop restart logs info doctor workspace enter db set settings unset edit ship test open share remove rebuild)
  COMPREPLY=( $(compgen -W "${cmds[*]}" -- "${COMP_WORDS[COMP_CWORD]}") )
}
complete -F _ld_complete ld
# ── Laradock 全局命令结束 ──
```

zsh 环境下，`complete` 行前加：

```bash
autoload -Uz bashcompinit && bashcompinit
```

（统一用 bash 补全语法，zsh 经 bashcompinit 兼容，避免两套补全语法。）

## README 更新（custom/README.md）

宿主机章节（93-147 行附近）改为：

- **主推**：`custom/scripts/setup_ld.sh` 一键配置（贴用法 + 各参数说明 + 生效/验证命令）。
- **备选**：保留现有手动抄写代码块，标注"或手动添加以下内容"。
- tab 补全小节改为"脚本默认包含；手动加则用下面代码"。

容器内章节、多套环境切换、加新服务等其余部分不动。

## 不做（YAGNI）

- 不做卸载/清理功能（未选）。
- 不做容器内 ~/.bashrc 配置（未选）。
- 不抽独立模板文件（当前仅一份配置块，抽模板属过度设计；
  将来新增容器内场景时可再抽）。

## 验证

- `./setup_ld.sh --dry-run`：预览正确，不写文件。
- `./setup_ld.sh --yes`：首次运行写入成功，rc 文件含配置块。
- 再次运行：提示已配置，不重复追加。
- 含手抄版 `ld()` 的 rc：先备份 `.bak.<时间戳>` 再替换。
- `--file /tmp/testrc`：不依赖 `$SHELL`，写入指定文件。
- zsh 环境（`SHELL=/usr/bin/zsh`，若可用）：写 `~/.zshrc` 且补全含 bashcompinit。
