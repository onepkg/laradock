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
  example-service/Dockerfile # 自定义服务模板（复制改名即新服务）
  README.md                 # 本文档
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

- `mysql`（8.x）：宿主机端口 3306，服务名（DNS 别名）`mysql`
- `mysql57`（5.7）：宿主机端口 3307，服务名（DNS 别名）`mysql57`
  （两者均未设置 `container_name`，真实容器名带 `COMPOSE_PROJECT_NAME` 前缀，如 `test_mysql-1`）
- 数据分别存于卷轴 `test_mysql-data` / `test_mysql57-data`

### 自定义服务

- `example-service`：自定义服务模板，复制 `custom/example-service/` 目录改名即新服务

## 加新服务

1. 需要自建镜像 → 新建 `custom/<svc>/Dockerfile`（参考 example-service 模板的
   长驻进程约定：带 `restart: always` 的镜像必须有前台长驻进程）
2. 在 `docker-compose.custom.yml` 的「新增服务区」加一段服务定义
   （镜像名 / build.context / ports / volumes / networks）
3. `docker compose config` 校验 → `docker compose build <svc>` → `docker compose up -d <svc>`

## 升级 Laradock

上游升级时直接 `git pull` 即可（本方案不改任何上游文件）。若上游改动
`docker-compose.yml` 的 include 列表或卷轴默认值，`custom/php-variants.yml`
与 `docker-compose.custom.yml` 一般无需变动；个别默认值变更可能需要在
`.env` 中显式覆盖。
