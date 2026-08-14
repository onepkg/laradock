# Laradock 自定义扩展（方案 A）

不改动任何上游文件，全部自定义集中在本目录与根目录的
`docker-compose.custom.yml`（个人文件，被 `.gitignore` 忽略）。

## 加载方式

`.env` 中设置：

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml
```

之后 `./laradock` 与 `docker compose` 自动合并加载。

## 目录结构

```
docker-compose.custom.yml   # 总入口：include + 卷轴 + 覆盖区 + 新增服务区（个人文件，不上库）
custom/
  php-fpm-73/compose.yml    # PHP 7.3 变体（extends 继承，仅 php-fpm 系）
  php-fpm-83/compose.yml    # PHP 8.3 变体（extends 继承，仅 php-fpm 系）
  example-service/Dockerfile # 自定义服务模板（复制改名即新服务）
  docker-compose.custom.yml.example  # 扩展示例模板（复制到根目录改名使用）
  README.md                 # 本文档
  <name>/compose.yml        # 自定义服务：每服务一个目录（services + 顶层 volumes）
```

## 日常使用

### 代码进命名卷轴

`projects-data` 卷轴（实际名 `test_projects-data`，前缀来自 `COMPOSE_PROJECT_NAME`）
挂载到 workspace / php-fpm 的 `/var/www/projects`。原 `/var/www` 宿主机构挂载保留。

```bash
./laradock workspace        # 进入容器
git clone <repo> /var/www/projects/<name>
cd /var/www/projects/<name> && composer install
```

数据持久于卷轴，宿主机不落盘。备用手段：

```bash
docker compose cp <host_path> workspace:/var/www/projects/
docker compose run --rm workspace bash
```

### PHP 版本切换

nginx 站点 conf 中：

```nginx
fastcgi_pass php-fpm-73:9000;   # PHP 7.3
fastcgi_pass php-fpm-83:9000;   # PHP 8.3
# 默认（主版本 PHP_VERSION）仍为 php-upstream / php-fpm:9000
```

CLI 侧：`./laradock workspace` 进入主版本；变体用
`docker compose exec php-fpm-73 bash` / `php-fpm-83`（无 workspace 变体）。

### 自定义 host（extra_hosts）

固定域名写在各服务的 `extra_hosts`（docker-compose.custom.yml 覆盖区、
custom/php-fpm-73|83/compose.yml 变体），IP 在 `.env` 变量化：

```env
MYAPP_IP=192.168.1.10
DB_IP=192.168.1.11
```

新增域名 = 在上述 `extra_hosts` 块加一行 `"域名": "${变量:-默认IP}"` +
`.env` 加对应 IP 变量。

### 数据库

- `mysql`（8.x）：宿主机端口 3306，服务名（DNS 别名）`mysql`
- `mysql57`（5.7）：宿主机端口 3307，服务名（DNS 别名）`mysql57`
  （两者均未设置 `container_name`，真实容器名带 `COMPOSE_PROJECT_NAME` 前缀，如 `test_mysql-1`）
- 数据分别存于卷轴 `test_mysql-data` / `test_mysql57-data`

### 自定义服务

- `example-service`：自定义服务模板，复制 `custom/example-service/` 目录改名即新服务

## 全局使用（任意目录 `ld` 命令）

CLI 要求必须在 laradock 目录内运行（`require_laradock_dir`），且 `APP_CODE_PATH_HOST`
是相对路径。用 shell 函数先 `cd` 进 laradock 目录再执行，即可在任何目录使用；
缩写 `ld`，避免与 laradock 目录内 `./laradock` 脚本及 compose 服务名冲突。
子 shell `( ... )` 包裹，不改变当前所在目录。

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

### workspace 容器内

laradock 目录默认未挂载进容器（仅 `projects-data:/var/www/projects` 代码卷），
需先让容器能看到 laradock 目录：

1. 在 `docker-compose.custom.yml` 的 workspace 块追加挂载（宿主机真实路径）：

   ```yaml
   workspace:
     volumes:
       - /var/www/github.com/onepkg/laradock:/laradock
   ```

2. 容器内 `~/.bashrc` 加：

   ```bash
   LARADOCK_DIR="/laradock"        # 容器内挂载点
   ld() { ( cd "$LARADOCK_DIR" && ./laradock "$@" ); }
   alias laradock='ld'
   ```

> 注意：容器内 `/root/.bashrc` 在重建后丢失（除非写进镜像或挂载持久卷），
> 常用就把挂载 + dotfiles 一起固化。

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

### 多套环境切换

```bash
LARADOCK_DIR=/path/to/another ld ps   # 临时指向其他 laradock 副本
```

## 加新服务

1. 需要自建镜像 → 新建 `custom/<svc>/Dockerfile`（参考 example-service 模板的
   长驻进程约定：带 `restart: always` 的镜像必须有前台长驻进程）
2. 在 `docker-compose.custom.yml` 的「新增服务区」加一段服务定义
   （镜像名 / build.context / ports / volumes / networks）
3. `docker compose config` 校验 → `docker compose build <svc>` → `docker compose up -d <svc>`

## 升级 Laradock

上游升级时直接 `git pull` 即可（本方案不改任何上游文件）。若上游改动
`docker-compose.yml` 的 include 列表或卷轴默认值，`custom/php-fpm-73|83/compose.yml`
与 `docker-compose.custom.yml` 一般无需变动；个别默认值变更可能需要在
`.env` 中显式覆盖。
