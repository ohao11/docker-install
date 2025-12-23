#!/bin/sh
set -eu

# 1. 权限检查
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 必须使用 root 权限运行此脚本。"
    exit 1
fi

# 2. 架构识别
arch=$(uname -m)
case "$arch" in
    x86_64)
        docker_tar="docker-x86-64.tgz"
        compose_bin="docker-compose-linux-x86_64"
        ;;
    aarch64|arm64)
        docker_tar="docker-aarch64.tgz"
        compose_bin="docker-compose-linux-aarch64"
        ;;
    *)
        echo "不支持的硬件架构: $arch"
        exit 1
        ;;
esac

script_dir=$(cd "$(dirname "$0")" && pwd)

# 3. 检查离线包是否存在
if [ ! -f "$script_dir/$docker_tar" ]; then echo "缺少文件: $script_dir/$docker_tar"; exit 1; fi
if [ ! -f "$script_dir/$compose_bin" ]; then echo "缺少文件: $script_dir/$compose_bin"; exit 1; fi

echo "检测到架构: $arch, 准备安装..."

# 4. 停止可能存在的旧服务
echo "停止旧服务 (如果存在)..."
systemctl stop docker docker.socket containerd 2>/dev/null || true

# 5. 解压并安装二进制
mkdir -p /usr/local/bin
echo "正在解压 $docker_tar ... "
tar -xzf "$script_dir/$docker_tar"
echo "正在提取二进制文件到 /usr/local/bin ..."
mv "$script_dir/docker/"* /usr/local/bin/

# 安装 docker-compose
echo "安装 docker-compose ..."
install -m 0755 "$script_dir/$compose_bin" /usr/local/bin/docker-compose

# 6. 配置用户组
getent group docker >/dev/null 2>&1 || groupadd docker
if [ "${SUDO_USER-}" ] && [ "$SUDO_USER" != "root" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "已将用户 $SUDO_USER 加入 docker 组"
fi

# 7. 创建必要的运行时目录
mkdir -p /etc/docker /run/containerd /var/lib/docker /var/lib/containerd

# 8. 写入 Systemd 配置
echo "配置 Systemd 服务..."

cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
After=network.target
[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
KillMode=process
Delegate=yes
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target containerd.service
Wants=network-online.target
Requires=containerd.service
[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd -H unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

# 清理旧的 socket 文件，防止激活冲突
if [ -f /etc/systemd/system/docker.socket ]; then
    systemctl disable docker.socket 2>/dev/null || true
    rm -f /etc/systemd/system/docker.socket
fi

# 9. 启动服务
echo "加载并启动服务..."
systemctl daemon-reload
systemctl enable containerd docker
systemctl restart containerd
systemctl restart docker

echo "安装流程结束。"