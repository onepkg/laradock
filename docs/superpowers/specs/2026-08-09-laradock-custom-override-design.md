# Laradock 自定义扩展设计（方案 A：全量 override 文件）

日期：2026-08-09
状态：已获用户确认

## 背景与目标

在本地使用 Laradock 时，需要以下自定义能力，同时保持对上游 **100% 升级兼容**（不改动任何原有文件，`git pull` 零冲突）：

1. **自定义服务**：v2raya（现成镜像）+ dbx/headroom（自建 Dockerfile，先给骨架）。
2. **PHP 多版本**：php7.3 / php8.3 的 php-fpm 与 workspace 变体，与主版本并存。
3. **自定义 host**：往 workspace/php-fpm 容器注入 自定义域名→IP（extra_hosts），IP 变量化放在 `.env`。
4. **代码命名卷轴**：新增 `code-data` 卷轴挂载到 `/var/www/projects`，供容器内 git 管理项目；**保留原有 `/var/www` 宿主机构挂载不动**。
5. **数据库命名卷轴**：mysql 与 mysql57 数据均用命名卷轴，替代 `DATA_PATH_HOST` 宿主机目录。
6. **MySQL 双实例**：8.x（现有 mysql 服务）+ 5.7（新增 mysql57 服务），独立卷轴与端口，同时运行。

## 核心机制（已实测验证）

采用 Docker Compose 多文件合并（`COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml`）：

- **同名服务覆盖**：override 中的服务定义与 base 合并。
- **卷轴按目标路径合并**：目标路径（container path）相同则后者替换前者；目标不同则追加。
- **extra_hosts 跨文件追加**：多值选项合并，原 `dockerhost` 保留。
- **命名卷轴自动加项目前缀**：`code-data` → `${COMPOSE_PROJECT_NAME}_code-data`（本机为 `test_code-data`）。

实测结论：

| 机制 | 结果 |
|---|---|
| 卷轴同目标替换（bind→命名卷轴）| ✅ 可行 |
| 卷轴新增挂载（不同目标）| ✅ 追加 |
| extra_hosts 跨文件合并 | ✅ 追加 |
| extra_hosts 变量化（空值安全）| ✅ 固定 key + `${VAR:-默认IP}` |
| extends 继承 + build context | ✅ 根目录 override 正确解析 |
| defaults.env 传递 | ✅ include + env_file 机制 |

**extra_hosts 变量化注意**：Compose 不支持"变量为空则跳过条目"，空条目会报 `invalid additional host`。故采用**固定 key mapping + 变量 IP** 形式：

```yaml
extra_hosts:
  "myapp.local": "${MYAPP_IP:-127.0.0.1}"
```

新增 host = override 文件加一行 key + `.env` 加对应 IP（或直接用默认值）。

## 文件布局

```
docker-compose.custom.yml      ← 总入口（个人文件，被 .gitignore 忽略，不上库）
custom/
  php-variants.yml             ← PHP 版本变体（extends 继承；提交到本 fork）
  dbx/Dockerfile               ← 骨架，用户后续自填
  headroom/Dockerfile          ← 骨架，用户后续自填
  README.md                    ← 扩展指南（提交）
.env                           ← 追加配置（个人文件，被 .gitignore 忽略）
docs/superpowers/specs/2026-08-09-laradock-custom-override-design.md ← 本设计文档
```

不改动任何原有文件。

## docker-compose.custom.yml 结构

```yaml
include:                        # 使 PHP 变体 extends 时正确解析 defaults.env
  - path: custom/php-variants.yml
    env_file:
      - php-fpm/defaults.env
      - workspace/defaults.env

volumes:                        # 命名卷轴（自动带 ${COMPOSE_PROJECT_NAME}_ 前缀）
  code-data:
  mysql-data:
  mysql57-data:
  dbx-data:
  headroom-data:
  v2raya-data:

services:
  # ---- 覆盖区：仅追加，不替换原有条目 ----
  workspace:
    volumes:
      - code-data:/var/www/projects
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
  php-fpm:
    volumes:
      - code-data:/var/www/projects
    extra_hosts:
      "myapp.local": "${MYAPP_IP:-127.0.0.1}"
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql      # 替换原 ${DATA_PATH_HOST}/mysql bind

  # ---- 新增服务区 ----
  mysql57:
    build:
      context: ./mysql
      args:
        MYSQL_VERSION: 5.7
    environment:                        # MYSQL57_* 变量（.env 提供）
      MYSQL_DATABASE: ${MYSQL57_DATABASE}
      MYSQL_USER: ${MYSQL57_USER}
      MYSQL_PASSWORD: ${MYSQL57_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL57_ROOT_PASSWORD}
      TZ: ${WORKSPACE_TIMEZONE}
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

### custom/php-variants.yml

仿照官方 `multi-php/compose.yml`，但独立成文件、不碰原文件：

```yaml
services:
  php-fpm-73:
    extends:
      file: ../php-fpm/compose.yml
      service: php-fpm
    build:
      context: ../php-fpm
      args:
        - LARADOCK_PHP_VERSION=7.3
  workspace-73:
    extends:
      file: ../workspace/compose.yml
      service: workspace
    build:
      context: ../workspace
      args:
        - LARADOCK_PHP_VERSION=7.3
  php-fpm-83:
    extends:
      file: ../php-fpm/compose.yml
      service: php-fpm
    build:
      context: ../php-fpm
      args:
        - LARADOCK_PHP_VERSION=8.3
  workspace-83:
    extends:
      file: ../workspace/compose.yml
      service: workspace
    build:
      context: ../workspace
      args:
        - LARADOCK_PHP_VERSION=8.3
```

### .env 追加项

```env
# ---- 自定义扩展（方案 A）----
# 加载自定义 compose 文件
COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml

# 自定义 host（extra_hosts）—— 固定域名，IP 在此变量化
MYAPP_IP=192.168.1.10

# MySQL 5.7 独立实例
MYSQL57_DATABASE=default
MYSQL57_USER=default
MYSQL57_PASSWORD=secret
MYSQL57_ROOT_PASSWORD=root
MYSQL57_PORT=3307
```

注意：`COMPOSE_FILE` 覆盖后，`./laradock` CLI 与 `docker compose` 会自动读取 `.env` 中的该值。

## 使用方式（写入 custom/README.md）

- **代码进卷轴**：`./laradock workspace` 进入容器 → `git clone` 项目到 `/var/www/projects` → 容器内编辑/提交（数据持久于 `test_code-data` 卷轴）。备用手段：`docker compose cp`、`docker compose run --rm workspace bash`。
- **切换 PHP 版本**：nginx 站点 conf 中 `fastcgi_pass php-fpm-73:9000;`（或 `php-fpm-83:9000`）。
- **加自定义 host**：override 文件 `extra_hosts` 小节加一行 key + `.env` 加 IP。
- **加新服务**：override 文件加一段服务 + 可选新建 `custom/<svc>/Dockerfile`，参照 `custom/README.md` 模板。
- **MySQL 连接**：8.x 用 `mysql:3306`、5.7 用 `mysql57:3306`（宿主机端口 3306/3307）。

## 风险与验证

1. **PHP 7.3 EOL**：`laradock/workspace:latest-7.3`、`laradock/php-fpm:latest-7.3` 基础镜像可能不可用或构建失败（workspace 已现代化到 Ubuntu 24.04）。实施时先 `docker compose build php-fpm-73 workspace-73` 验证；失败则与用户讨论降级（如 7.4）。
2. **MySQL 5.7 旧镜像**：`mysql:5.7` 为受支持版本，但官方镜像已进入维护期；`mysql/Dockerfile` 中 `MYSQL_MAJOR` 由基础镜像提供，5.7 时 8.0 分支不生效，正常。
3. **覆盖合并语义**：核心机制已实测（见上表），实施后以 `docker compose config` 复验完整配置。

## 范围外（本次不做）

- 不改动任何上游文件（`docker-compose.yml`、各 `*/compose.yml`、`multi-php/`、CLI）。
- 不迁移 `DATA_PATH_HOST` 中的存量 mysql 数据到卷轴（用户以 git 全新工作流为主；如需要可手动 `docker cp` 迁移）。
- dbx/headroom 的具体业务逻辑（用户自填骨架）。
