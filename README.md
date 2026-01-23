# Docker 离线安装包

本目录包含 Docker Community Edition (CE) 和 Docker Compose 的离线安装脚本及二进制文件。支持 x86_64 和 ARM64 (aarch64) 架构。

## 包含文件说明

- `install-docker-offline.sh`: 自动化安装脚本
- `docker-x86-64.tgz`: x86_64 架构的 Docker 二进制包
- `docker-aarch64.tgz`: ARM64 架构的 Docker 二进制包
- `docker-compose-linux-x86_64`: x86_64 架构的 Docker Compose
- `docker-compose-linux-aarch64`: ARM64 架构的 Docker Compose

## 安装步骤

### 1. 准备工作

确保将整个目录复制到目标机器上。

### 2. 运行安装脚本

使用 root 权限运行安装脚本：

```bash
# 进入目录
cd /path/to/docker-install

# 赋予脚本执行权限（可选）
chmod +x install-docker-offline.sh

# 运行安装脚本
sudo ./install-docker-offline.sh
```

脚本会自动检测系统架构（x86_64 或 aarch64）并安装对应的版本。

**脚本执行的操作：**
1. 检查 root 权限。
2. 识别系统架构。
3. 停止旧的 Docker 服务（如果存在）。
4. 解压并安装 Docker 二进制文件到 `/usr/local/bin`。
5. 安装 Docker Compose 到 `/usr/local/bin`。
6. 创建 `docker` 用户组，并将当前 sudo 用户加入该组。
7. 配置并启动 Systemd 服务 (`docker.service`, `containerd.service`)。

### 3. 验证安装

安装完成后，验证 Docker 和 Docker Compose 是否正常工作：

```bash
# 查看 Docker 版本
docker --version

# 查看 Docker Compose 版本
docker-compose --version

# 运行 Hello World 测试
docker run --rm hello-world
```

### 4. 用户权限说明

脚本会自动尝试将执行脚本的 sudo 用户添加到 `docker` 组。
为了让组权限生效，您可能需要：
- 重新登录当前会话
- 或者运行 `newgrp docker` 命令

## 手动卸载

如果需要卸载，请执行以下命令：

```bash
# 停止服务
sudo systemctl stop docker containerd

# 删除二进制文件
sudo rm -rf /usr/local/bin/docker*
sudo rm -rf /usr/local/bin/containerd*
sudo rm -rf /usr/local/bin/runc
sudo rm -rf /usr/local/bin/ctr

# 删除配置和服务文件
sudo rm -rf /etc/docker
sudo rm -rf /etc/systemd/system/docker.service
sudo rm -rf /etc/systemd/system/containerd.service
sudo systemctl daemon-reload

# (可选) 删除数据目录 - 警告：这将删除所有容器和镜像！
# sudo rm -rf /var/lib/docker
# sudo rm -rf /var/lib/containerd
```
