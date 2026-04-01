# NAS媒体库管理工具

> 本项目 fork 自上游仓库 `TonyLiooo/nas-tools`：https://github.com/TonyLiooo/nas-tools


[![GitHub stars](https://img.shields.io/github/stars/iMMIQ/nas-tools?style=plastic)](https://github.com/iMMIQ/nas-tools/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/iMMIQ/nas-tools?style=plastic)](https://github.com/iMMIQ/nas-tools/network/members)
[![GitHub issues](https://img.shields.io/github/issues/iMMIQ/nas-tools?style=plastic)](https://github.com/iMMIQ/nas-tools/issues)
[![GitHub license](https://img.shields.io/github/license/iMMIQ/nas-tools?style=plastic)](https://github.com/iMMIQ/nas-tools/blob/master/LICENSE.md)
[![Docker pulls](https://img.shields.io/docker/pulls/iMMIQ/nas-tools?style=plastic)](https://hub.docker.com/r/iMMIQ/nas-tools)
[![Platform](https://img.shields.io/badge/platform-amd64/arm64-pink?style=plastic)](https://hub.docker.com/r/iMMIQ/nas-tools)

Docker：https://hub.docker.com/repository/docker/iMMIQ/nas-tools



## 功能：

1. 优化用户认证
2. 优化新手刷流体验
1. 刷流任务优化：
   * 增加部分下载能力（拆包）
   * 增加限免到期检测能力
   * 刷流界面增加详细信息展示
3. 支持 BT 能力和内置 BT 站点，可以索引和下载 BT 磁链和种子文件
4. 支持 jackett 和 prowlarr 索引器
5. 增加一些入口的快捷跳转能力
6. 完美支持 Mteam 新架构

详细参考 [这里](diff.md)。

## 安装
### 1、Docker
```
docker pull iMMIQ/nas-tools:latest
```
教程见 [这里](docker/readme.md) 。

Docker 镜像现采用不可变部署策略：请保持 `NASTOOL_AUTO_UPDATE=false`，升级时重新 build / pull 新镜像并重建容器；如无法连接 GitHub，可将 `NASTOOL_CN_UPDATE=true` 以使用国内源加速依赖安装。

### 2、懒猫微服

项目已添加懒猫微服部署支持，仓库根目录包含以下文件：

- `package.yml`
- `lzc-manifest.yml`
- `lzc-build.yml`

部署前请先安装并配置 `lzc-cli`、`docker buildx`，然后在项目根目录执行：

```bash
./scripts/deploy_lazycat.sh
```

如需指定微服名称：

```bash
./scripts/deploy_lazycat.sh --box immiqtop
```

部署后，应用配置会自动写入 `/config/config.yaml`，首次使用时可重点关注这些容器内路径：

- `/config`：应用配置、数据库、插件与浏览器持久数据
- `/cache`：日志、临时文件、TMDB 缓存、webdriver 下载
- `/lzcapp/media/RemoteFS`：懒猫媒体挂载
- `/lzcapp/document`：懒猫文稿挂载

懒猫环境默认采用不可变镜像：请保持 `NASTOOL_AUTO_UPDATE=false`，通过重新构建镜像并重新部署 LPK 的方式升级应用。

### 3、本地运行
推荐使用 `uv` 管理依赖，仓库中的 `pyproject.toml` 和 `uv.lock` 为唯一依赖源：
```
git clone -b master https://github.com/iMMIQ/nas-tools --recurse-submodule
cd nas-tools
uv sync --frozen
export NASTOOL_CONFIG="/xxx/config/config.yaml"
nohup uv run python run.py &
```

如需更新锁文件，可在调整 `pyproject.toml` 后执行：
```
uv lock
```
## 常见问题
请参考 [常见问题](Q&A.md)

## 免责声明
1) 本软件不提供任何内容，仅作为辅助工具简化用户手工操作，对用户的行为及内容毫不知情，使用本软件产生的任何责任需由使用者本人承担。
2) 本软件代码开源，基于开源代码进行修改，人为去除相关限制导致软件被分发、传播并造成责任事件的，需由代码修改发布者承担全部责任。同时按AGPL-3.0开源协议要求，基于此软件代码的所有修改必须开源。
3) 所有搜索结果均来自源站，本软件不承担任何责任
3) 本软件仅供学习交流，请保持低调，勿公开传播
