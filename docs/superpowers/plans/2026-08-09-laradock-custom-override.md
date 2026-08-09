# Laradock 自定义扩展（方案 A）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改动任何上游文件的前提下，为 Laradock 增加自定义服务（v2raya/dbx/headroom）、PHP 7.3/8.3 版本变体、extra_hosts 自定义域名注入，以及代码/数据库命名卷轴，全部通过一个 `docker-compose.custom.yml` override 文件实现。

**Architecture:** 利用 Docker Compose 多文件合并（`COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml`）：同名服务合并、卷轴按目标路径追加/替换、extra_hosts 追加。PHP 版本变体通过 `extends` 继承现有 php-fpm/workspace 定义，并经 `include` + `env_file` 使 defaults.env 的 build args 正确解析。

**Tech Stack:** Docker Compose v2.20+（本机 v5.1.4）、Laradock 现有 Dockerfile（mysql）、基础镜像 laradock/workspace 与 laradock/php-fpm、alpine（dbx/headroom 骨架）。

## Global Constraints

- **不改动任何上游文件**：`docker-compose.yml`、各 `*/compose.yml`、`multi-php/`、`laradock` CLI 等一律不动；上游 `git pull` 必须零冲突。
- `docker-compose.custom.yml` 与 `.env` 被上游 `.gitignore` 忽略（`docker-compose.custom.yml` 在忽略列表中）——**不得强制 `git add -f` 提交**；只有 `custom/` 目录内容提交到本 fork。
- 命名卷轴 `code-data` 挂载到 `/var/www/projects`（新增），**保留**原 `${APP_CODE_PATH_HOST}:${APP_CODE_PATH_CONTAINER}:cached`（`/var/www`）bind mount 不动。
- extra_hosts 采用**固定 key mapping + `${VAR:-默认IP}`** 形式；Compose 不支持空条目（空字符串会报 `invalid additional host`），不得使用 `- "${VAR:-}"` 空槽位模式。
- PHP 变体必须经 `include` + `env_file: [php-fpm/defaults.env, workspace/defaults.env]` 加载，否则 `BASE_IMAGE_TAG_PREFIX` 等 build args 解析为空（镜像名会变成 `laradock/php-fpm:-7.3`）。
- 注释用中文；commit message 用中文、遵循 Conventional Commits。
- 每个任务的验证均以 `docker compose config` 输出断言为准。

---

### Task 1: custom/php-variants.yml（PHP 版本变体）

**Files:**
- Create: `custom/php-variants.yml`

**Interfaces:**
- Consumes: 上游 `php-fpm/compose.yml`、`workspace/compose.yml`（extends 源）
- Produces: 服务 `php-fpm-73`、`workspace-73`、`php-fpm-83`、`workspace-83`（供 Task 3 的 include 使用）；变量 `MYAPP_IP`、`DB_IP`（默认 `127.0.0.1`，来自 .env）

- [ ] **Step 1: 创建文件**

写入 `custom/php-variants.yml`：

```yaml
# PHP 版本变体：通过 extends 继承 php-fpm / workspace 的真实定义，
# 仅覆盖 LARADOCK_PHP_VERSION 并追加自定义 extra_hosts。
#
# 本文件由 docker-compose.custom.yml 通过 include + env_file 加载。
# env_file 提供 php-fpm/defaults.env 与 workspace/defaults.env，
# 使继承的 build args（BASE_IMAGE_TAG_PREFIX、INSTALL_* 等）正确解析。
# 若缺失，BASE_IMAGE_TAG_PREFIX 会解析为空，镜像名将变成 laradock/php-fpm:-7.3。
#
# 新增版本：复制一对服务块，修改服务名与 LARADOCK_PHP_VERSION 即可。

services:

  # ---------- PHP 7.3 ----------
  php-fpm-73:
    extends:
      file: ../php-fpm/compose.yml
      service: php-fpm
    build:
      context: ../php-fpm
      args:
        - LARADOCK_PHP_VERSION=7.3
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"

  workspace-73:
    extends:
      file: ../workspace/compose.yml
      service: workspace
    build:
      context: ../workspace
      args:
        - LARADOCK_PHP_VERSION=7.3
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"

  # ---------- PHP 8.3 ----------
  php-fpm-83:
    extends:
      file: ../php-fpm/compose.yml
      service: php-fpm
    build:
      context: ../php-fpm
      args:
        - LARADOCK_PHP_VERSION=8.3
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"

  workspace-83:
    extends:
      file: ../workspace/compose.yml
      service: workspace
    build:
      context: ../workspace
      args:
        - LARADOCK_PHP_VERSION=8.3
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"
```

- [ ] **Step 2: 验证 4 个变体服务解析正确**

创建临时验证入口 `.verify-inc.yml`（验证后删除）：

```yaml
include:
  - path: custom/php-variants.yml
    env_file:
      - php-fpm/defaults.env
      - workspace/defaults.env
```

运行：

```bash
docker compose -f docker-compose.yml -f .verify-inc.yml --env-file .env.example config
```

断言（预期全部满足）：
- 出现 `php-fpm-73`、`workspace-73`、`php-fpm-83`、`workspace-83` 四个服务
- 每个的 `build.context` = `<仓库根>/php-fpm` 或 `<仓库根>/workspace`
- 每个的 `build.args.BASE_IMAGE_TAG_PREFIX` = `latest`（非空）
- 每个的 `build.args.LARADOCK_PHP_VERSION` = 对应版本（7.3 / 8.3）
- 每个的 `extra_hosts` 含 `myapp.local=127.0.0.1`、`db.local=127.0.0.1`（变量未设时走默认值）

实际执行（可用 grep 定向断言）：

```bash
docker compose -f docker-compose.yml -f .verify-inc.yml --env-file .env.example config \
  | grep -A45 "^  php-fpm-73:" | grep -E "BASE_IMAGE_TAG_PREFIX|LARADOCK_PHP_VERSION|myapp.local"
```

预期输出含 `BASE_IMAGE_TAG_PREFIX: latest`。

若 `LARADOCK_PHP_VERSION` 为 7.3 但上下文不对，检查 `context: ../php-fpm` 是否相对 `custom/` 目录。

- [ ] **Step 3: 删除临时文件并提交**

```bash
rm -f .verify-inc.yml
git add custom/php-variants.yml
git commit -m "feat: 添加 PHP 7.3/8.3 版本变体（custom/php-variants.yml）"
```

---

### Task 2: dbx / headroom Dockerfile 骨架

**Files:**
- Create: `custom/dbx/Dockerfile`
- Create: `custom/headroom/Dockerfile`

**Interfaces:**
- Consumes: 无
- Produces: 构建上下文目录 `custom/dbx/`、`custom/headroom/`（Task 4 的 dbx/headroom 服务依赖其存在；`docker compose config` 会校验 build context 存在性）

- [ ] **Step 1: 创建 dbx 骨架**

写入 `custom/dbx/Dockerfile`：

```dockerfile
# dbx —— 自定义工具服务（骨架）
# 占位实现：后续将 FROM、依赖安装和启动逻辑替换为真实内容。
# 注意：该服务带 restart: always，镜像必须包含前台长驻进程，
# 否则容器会不断重启（crash-loop）。
FROM alpine:3.20

RUN apk add --no-cache bash

# 卷轴 dbx-data 挂载于 /data，用于持久化
WORKDIR /data

# 占位长驻进程：后续替换为你的真实入口
CMD ["sh", "-c", "echo '[dbx] skeleton placeholder, replace CMD in custom/dbx/Dockerfile'; while true; do sleep 3600; done"]
```

- [ ] **Step 2: 创建 headroom 骨架**

写入 `custom/headroom/Dockerfile`：

```dockerfile
# headroom —— 自定义工具服务（骨架）
# 占位实现：后续将 FROM、依赖安装和启动逻辑替换为真实内容。
# 注意：该服务带 restart: always，镜像必须包含前台长驻进程，
# 否则容器会不断重启（crash-loop）。
FROM alpine:3.20

RUN apk add --no-cache bash

# 卷轴 headroom-data 挂载于 /data，用于持久化
WORKDIR /data

# 占位长驻进程：后续替换为你的真实入口
CMD ["sh", "-c", "echo '[headroom] skeleton placeholder, replace CMD in custom/headroom/Dockerfile'; while true; do sleep 3600; done"]
```

- [ ] **Step 3: 验证 Dockerfile 可构建**

```bash
docker build -t tmp-dbx ./custom/dbx
docker build -t tmp-headroom ./custom/headroom
```

预期：两命令均成功退出（`Successfully tagged tmp-dbx:latest` 等），无报错。

- [ ] **Step 4: 清理并提交**

```bash
docker rmi tmp-dbx tmp-headroom >/dev/null 2>&1
git add custom/dbx/Dockerfile custom/headroom/Dockerfile
git commit -m "feat: 添加 dbx/headroom 自定义服务 Dockerfile 骨架"
```

---

### Task 3: docker-compose.custom.yml 覆盖区（include + 卷轴 + 基础服务覆盖）

**Files:**
- Create: `docker-compose.custom.yml`（被 .gitignore 忽略，不提交）

**Interfaces:**
- Consumes: Task 1 的 `custom/php-variants.yml`
- Produces: 文件 `docker-compose.custom.yml`（Task 4 继续追加）；`docker compose -f docker-compose.yml -f docker-compose.custom.yml` 成为本任务及后续的验证入口

- [ ] **Step 1: 创建文件（覆盖区部分）**

写入 `docker-compose.custom.yml`：

```yaml
# Laradock 个人自定义扩展（方案 A）
# 本文件被 .gitignore 忽略，属个人配置，不进版本库。
# 通过 .env 的 COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml 合并加载。
#
# 结构：
#   1. include —— 加载 PHP 版本变体（Task 1），并提供 php-fpm/workspace 的 defaults.env
#   2. volumes —— 顶层命名卷轴
#   3. 覆盖区 —— workspace / php-fpm / mysql 的卷轴与 extra_hosts 追加/替换
#   4. 新增区 —— mysql57 / v2raya / dbx / headroom（Task 4 追加）

include:
  - path: custom/php-variants.yml
    env_file:
      - php-fpm/defaults.env
      - workspace/defaults.env

volumes:
  code-data:
  mysql-data:
  mysql57-data:
  dbx-data:
  headroom-data:
  v2raya-data:

services:

  # ============ 覆盖区：仅追加/替换，保留原有挂载 ============

  workspace:
    volumes:
      - code-data:/var/www/projects
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"

  php-fpm:
    volumes:
      - code-data:/var/www/projects
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
      "db.local": "${DB_IP:-127.0.0.1}"

  mysql:
    volumes:
      - mysql-data:/var/lib/mysql
```

- [ ] **Step 2: 验证覆盖语义正确**

```bash
docker compose -f docker-compose.yml -f docker-compose.custom.yml --env-file .env config
```

断言：
- `workspace` 服务 volumes **同时**包含：
  - 原 bind：`type: bind, source: <host 路径>, target: /var/www`（保留）
  - 新卷轴：`type: volume, source: <项目前缀>_code-data, target: /var/www/projects`
- `workspace` 的 extra_hosts 含 `dockerhost=10.0.75.1`（来自上游）+ `myapp.local=127.0.0.1` + `db.local=127.0.0.1`
- `php-fpm` 服务同上（bind 保留 + code-data 卷轴 + extra_hosts 合并）
- `mysql` 服务 volumes 为 `type: volume, source: <前缀>_mysql-data, target: /var/lib/mysql`（原 `${DATA_PATH_HOST}/mysql` bind 已被替换）
- 顶层 volumes 含 `code-data`、`mysql-data`、`mysql57-data`、`dbx-data`、`headroom-data`、`v2raya-data`
- 四个 PHP 变体服务存在且 `BASE_IMAGE_TAG_PREFIX: latest`

定向断言命令（workspace 卷轴/extra_hosts）：

```bash
docker compose -f docker-compose.yml -f docker-compose.custom.yml --env-file .env config \
  | grep -A60 "^  workspace:" | grep -E "target: /var/www|source:.*code-data|myapp.local|db.local|dockerhost"
```

预期输出同时含 `target: /var/www`、`/var/www/projects`、`dockerhost`、`myapp.local`、`db.local`。

> 若 mysql 的 bind 未被替换（同时出现两个 /var/lib/mysql），说明合并语义异常，先检查 mysql/compose.yml 当前实际挂载目标再定位。

- [ ] **Step 3: 确认 git 状态不含该文件**

```bash
git status --porcelain
```

预期：`docker-compose.custom.yml` 不出现在未跟踪列表中（被 .gitignore 忽略）。本任务无提交。

---

### Task 4: 新增服务区（mysql57 / v2raya / dbx / headroom）+ .env 变量

**Files:**
- Modify: `docker-compose.custom.yml`（追加新增服务区）
- Modify: `.env`（追加 MYSQL57_*、MYAPP_IP、DB_IP；**暂不**改 COMPOSE_FILE）

**Interfaces:**
- Consumes: Task 2 的 `custom/dbx/`、`custom/headroom/` 上下文
- Produces: 服务 `mysql57`、`v2raya`、`dbx`、`headroom`；`.env` 变量 `MYAPP_IP`、`DB_IP`、`MYSQL57_DATABASE`、`MYSQL57_USER`、`MYSQL57_PASSWORD`、`MYSQL57_ROOT_PASSWORD`、`MYSQL57_PORT`

- [ ] **Step 1: 在 docker-compose.custom.yml 追加新增服务区**

在 `mysql:` 覆盖块之后追加：

```yaml

  # ============ 新增服务区 ============

  mysql57:
    restart: always
    build:
      context: ./mysql
      args:
        - MYSQL_VERSION=5.7
    environment:
      - MYSQL_DATABASE=${MYSQL57_DATABASE}
      - MYSQL_USER=${MYSQL57_USER}
      - MYSQL_PASSWORD=${MYSQL57_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL57_ROOT_PASSWORD}
      - TZ=${WORKSPACE_TIMEZONE}
    volumes:
      - mysql57-data:/var/lib/mysql
      - ./mysql/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d
    ports:
      - "${MYSQL57_PORT}:3306"
    networks:
      - backend

  v2raya:
    image: mzz2017/v2raya
    restart: always
    ports:
      - "2017:2017"
    volumes:
      - v2raya-data:/etc/v2raya
    cap_add:
      - NET_ADMIN
    networks:
      - backend

  dbx:
    build:
      context: ./custom/dbx
    restart: always
    volumes:
      - dbx-data:/data
    networks:
      - backend

  headroom:
    build:
      context: ./custom/headroom
    restart: always
    volumes:
      - headroom-data:/data
    networks:
      - backend
```

> 说明：`mysql57` 的 initdb 挂载用**字面量** `./mysql/docker-entrypoint-initdb.d`（与 mysql/defaults.env 中 `MYSQL_ENTRYPOINT_INITDB` 的默认值一致）。不要在此文件引用 `${MYSQL_ENTRYPOINT_INITDB}`——override 文件不继承 mysql/defaults.env，会解析为空导致挂载源非法。

- [ ] **Step 2: 在 .env 追加变量（不改 COMPOSE_FILE）**

在 `.env` 末尾追加：

```env

# ---- 自定义扩展（方案 A）----
# 自定义 host（extra_hosts 注入容器 /etc/hosts）
MYAPP_IP=127.0.0.1
DB_IP=127.0.0.1

# MySQL 5.7 独立实例
MYSQL57_DATABASE=default
MYSQL57_USER=default
MYSQL57_PASSWORD=secret
MYSQL57_ROOT_PASSWORD=root
MYSQL57_PORT=3307
```

（`MYAPP_IP`、`DB_IP` 请按实际需求改成真实 IP。）

- [ ] **Step 3: 验证新增服务解析与构建**

```bash
docker compose -f docker-compose.yml -f docker-compose.custom.yml --env-file .env config
```

断言：
- 出现 `mysql57`、`v2raya`、`dbx`、`headroom` 四个服务
- `mysql57.build.args.MYSQL_VERSION` = `5.7`；`mysql57.environment.MYSQL_DATABASE` = `default`（来自 .env）；`mysql57.ports` 含 `3307` 宿主端口；volumes 含 `<前缀>_mysql57-data` 与 `./mysql/docker-entrypoint-initdb.d`
- `v2raya.image` = `mzz2017/v2raya`；cap_add 含 `NET_ADMIN`
- `dbx.build.context`、`headroom.build.context` 指向 `custom/dbx`、`custom/headroom`（目录已存在）

构建轻量镜像验证：

```bash
docker compose -f docker-compose.yml -f docker-compose.custom.yml build dbx headroom mysql57
```

预期：三个镜像构建成功（dbx/headroom 为 alpine 基础，秒级；mysql57 拉取 mysql:5.7 基础镜像）。

- [ ] **Step 4: 确认 git 状态**

```bash
git status --porcelain
```

预期：新增/修改均只涉及 gitignored 的 `docker-compose.custom.yml` 与 `.env`，无待提交改动。本任务无提交。

---

### Task 5: 启用 COMPOSE_FILE 全量合并 + 端到端验证

**Files:**
- Modify: `.env`（修改 `COMPOSE_FILE`）

**Interfaces:**
- Consumes: Task 3/4 完整的 `docker-compose.custom.yml`
- Produces: 生效的 `COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml`，使 `./laradock` CLI 与 `docker compose` 默认即加载自定义扩展

- [ ] **Step 1: 修改 .env 的 COMPOSE_FILE**

将 `.env` 中现有行：

```env
COMPOSE_FILE=docker-compose.yml
```

改为：

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml
```

- [ ] **Step 2: 验证默认命令即加载自定义配置**

```bash
docker compose config
```

（不带任何 `-f` 或 `--env-file`；`docker compose` 自动读取 `.env` 中的 `COMPOSE_FILE`。）

断言：与 Task 4 Step 3 的完整输出一致（含 mysql57/v2raya/dbx/headroom、PHP 变体、code-data 卷轴、extra_hosts）。

- [ ] **Step 3: 验证 ./laradock CLI 兼容**

```bash
./laradock info
```

预期：CLI 正常列出服务（含自定义服务），无报错。若 `info` 命令不展示服务列表，改用 `./laradock ps`（透传 `docker compose ps`，此时容器未启动会显示空列表，属正常）。

- [ ] **Step 4: 验证上游未被动过**

```bash
git status --porcelain
```

预期：仅 gitignored 文件有改动（不出现在列表）；无任何上游文件被修改。

---

### Task 6: custom/README.md 扩展指南

**Files:**
- Create: `custom/README.md`

**Interfaces:**
- Consumes: 全部已实现能力
- Produces: 使用与扩展文档（提交到本 fork）

- [ ] **Step 1: 创建 README**

写入 `custom/README.md`：

````markdown
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
  php-variants.yml          # PHP 7.3 / 8.3 版本变体（extends 继承）
  dbx/Dockerfile            # 自定义服务骨架（待填充）
  headroom/Dockerfile       # 自定义服务骨架（待填充）
  README.md                 # 本文档
```

## 日常使用

### 代码进命名卷轴

`code-data` 卷轴（实际名 `test_code-data`，前缀来自 `COMPOSE_PROJECT_NAME`）
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
`docker compose exec workspace-73 bash` / `workspace-83`。

### 自定义 host（extra_hosts）

固定域名写在各服务的 `extra_hosts`（docker-compose.custom.yml 覆盖区、
custom/php-variants.yml 变体），IP 在 `.env` 变量化：

```env
MYAPP_IP=192.168.1.10
DB_IP=192.168.1.11
```

新增域名 = 在上述 `extra_hosts` 块加一行 `"域名": "${变量:-默认IP}"` +
`.env` 加对应 IP 变量。

### 数据库

- `mysql`（8.x）：宿主机端口 3306，容器名 `mysql`
- `mysql57`（5.7）：宿主机端口 3307，容器名 `mysql57`
- 数据分别存于卷轴 `test_mysql-data` / `test_mysql57-data`

### 自定义服务

- `v2raya`：`http://localhost:2017`（需 NET_ADMIN）
- `dbx` / `headroom`：骨架镜像，`custom/<name>/Dockerfile` 待填充

## 加新服务

1. 需要自建镜像 → 新建 `custom/<svc>/Dockerfile`（参考 dbx 骨架的
   长驻进程约定：带 `restart: always` 的镜像必须有前台长驻进程）
2. 在 `docker-compose.custom.yml` 的「新增服务区」加一段服务定义
   （镜像名 / build.context / ports / volumes / networks）
3. `docker compose config` 校验 → `docker compose build <svc>` → `docker compose up -d <svc>`

## 升级 Laradock

上游升级时直接 `git pull` 即可（本方案不改任何上游文件）。若上游改动
`docker-compose.yml` 的 include 列表或卷轴默认值，`custom/php-variants.yml`
与 `docker-compose.custom.yml` 一般无需变动；个别默认值变更可能需要在
`.env` 中显式覆盖。
````

- [ ] **Step 2: 提交**

```bash
git add custom/README.md
git commit -m "docs: 添加 Laradock 自定义扩展使用指南"
```

---

### Task 7: PHP 7.3 构建风险验证（慢，约 10-30 分钟）

**Files:** 无新增

**Interfaces:**
- Consumes: Task 1 的 `php-fpm-73` / `workspace-73`、Task 3 的 include 加载
- Produces: 验证结论（PHP 7.3 基础镜像是否可用）；若失败，产出与用户讨论的降级建议

- [ ] **Step 1: 构建 PHP 7.3 变体**

```bash
docker compose build php-fpm-73 workspace-73
```

预期：两镜像构建成功。

> 说明：该步骤会拉取 `laradock/php-fpm:latest-7.3`、`laradock/workspace:latest-7.3`
> 基础镜像并执行完整构建，耗时较长。构建日志中出现 `Successfully built` 即通过。

- [ ] **Step 2: 处理失败场景（若发生）**

若 Step 1 因基础镜像不存在、拉取失败或构建错误而失败：

- 记录失败的具体报错（镜像 tag 不存在 / 依赖编译失败等）
- **停止执行**，将报错整理后与用户讨论，按 spec 风险项给出候选方案（如改 7.4、固定
  BASE_IMAGE_TAG_PREFIX 旧 tag、或放弃 7.3 仅保留 8.3），不擅自改动设计。

- [ ] **Step 3: 收尾检查**

```bash
docker compose config >/dev/null && echo "CONFIG OK"
git status --porcelain
```

预期：`CONFIG OK`；无上游文件改动。全部任务完成后向用户汇报。
