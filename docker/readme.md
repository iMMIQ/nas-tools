## 特点

- 基于alpine实现，镜像体积小；

- 镜像层数少；

- 支持 amd64/arm64 架构；

- 采用不可变镜像部署，升级时重新拉取/构建镜像并重建容器；

- 可以以非root用户执行任务，降低程序权限和潜在风险；

- 可以设置文件掩码权限umask。

- 集成完全插件（no authentication required）

## 创建

**注意**

- 媒体目录的设置必须符合 [配置说明](https://github.com/iMMIQ/nas-tools#%E9%85%8D%E7%BD%AE) 的要求。

- umask含义详见：http://www.01happy.com/linux-umask-analyze 。

- 创建后请根据 [配置说明](https://github.com/iMMIQ/nas-tools#%E9%85%8D%E7%BD%AE) 及该文件本身的注释，修改`config/config.yaml`，修改好后再重启容器，最后访问`http://<ip>:<web_port>`。

**docker cli**

```
docker run -d \
    --name nas-tools \
    --hostname nas-tools \
    -p 3000:3000   `# 默认的webui控制端口` \
    -v $(pwd)/config:/config  `# 持久化配置、数据库、插件` \
    -v $(pwd)/cache:/cache  `# 日志、临时缓存、webdriver` \
    -v /你的媒体目录:/你想设置的容器内能见到的目录    `# 媒体目录，多个目录需要分别映射进来` \
    -e PUID=0     `# 想切换为哪个用户来运行程序，该用户的uid，详见下方说明` \
    -e PGID=0     `# 想切换为哪个用户来运行程序，该用户的gid，详见下方说明` \
    -e UMASK=000  `# 掩码权限，默认000，可以考虑设置为022` \
    -e NASTOOL_AUTO_UPDATE=false `# 保持关闭，镜像升级请通过重建容器完成` \
    -e NASTOOL_CN_UPDATE=true `# 需要国内源访问部分外部资源时可保持开启` \
    iMMIQ/nas-tools
```

**docker-compose**

新建`docker-compose.yaml`文件如下，并以命令`docker-compose up -d`启动。

```
version: "3"
services:
  nas-tools:
    image: iMMIQ/nas-tools:latest
    ports:
      - 3000:3000        # 默认的webui控制端口
    volumes:
      - ./config:/config   # 持久化配置、数据库、插件
      - ./cache:/cache     # 持久化日志与缓存目录
      - /你的媒体目录:/你想设置的容器内能见到的目录   # 媒体目录，多个目录需要分别映射进来，需要满足配置文件说明中的要求
    environment: 
      - PUID=0    # 想切换为哪个用户来运行程序，该用户的uid
      - PGID=0    # 想切换为哪个用户来运行程序，该用户的gid
      - UMASK=000 # 掩码权限，默认000，可以考虑设置为022
      - NASTOOL_AUTO_UPDATE=false  # 保持关闭，镜像升级请通过重建容器完成
      - NASTOOL_CN_UPDATE=true # 需要国内源访问部分外部资源时可保持开启
    restart: always
    network_mode: bridge
    hostname: nas-tools
    container_name: nas-tools
```

## 后续如何更新

- 拉取或构建新镜像。

- 删除旧容器并使用新镜像重新创建容器。

- 保留原有 `/config`、新增 `/cache`，并继续挂载媒体目录即可完成升级。

## 关于PUID/PGID的说明

- 如在使用诸如emby、jellyfin、plex、qbittorrent、transmission、deluge、jackett、sonarr、radarr等等的docker镜像，请保证创建本容器时的PUID/PGID和它们一样。

- 在docker宿主上，登陆媒体文件所有者的这个用户，然后分别输入`id -u`和`id -g`可获取到uid和gid，分别设置为PUID和PGID即可。

- `PUID=0` `PGID=0`指root用户，它拥有最高权限，若你的媒体文件的所有者不是root，不建议设置为`PUID=0` `PGID=0`。
