#!/bin/sh

# ==== 可通过环境变量自定义 ====
PORT=${PORT:-16805}
USERNAME=${USERNAME:-"user"}
PASSWORD=${PASSWORD:-"pass"}

# ==== 卸载逻辑 ====
if [ "$1" = "uninstall" ]; then
  echo "[卸载] 停止并移除 sing-box..."
  if [ -f /etc/init.d/sing-box ]; then
    rc-service sing-box stop
    rc-update del sing-box
    rm -f /etc/init.d/sing-box
  fi

  if [ -f /etc/systemd/system/sing-box.service ]; then
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload
  fi

  rm -rf /etc/sing-box
  rm -f /usr/local/bin/sing-box
  echo "✅ 卸载完成"
  exit 0
fi

# ==== 安装依赖 ====
echo "[INFO] 检测系统并安装 curl tar unzip..."
if [ -f /etc/alpine-release ]; then
  apk update && apk add curl tar unzip
else
  command -v apt && apt update && apt install -y curl tar unzip || true
  command -v yum && yum install -y curl tar unzip || true
fi

# ==== 获取系统架构 ====
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_ID="amd64" ;;
  aarch64) ARCH_ID="arm64" ;;
  armv7l) ARCH_ID="armv7" ;;
  *) echo "❌ 不支持的架构: $ARCH" && exit 1 ;;
esac

# ==== 下载并安装 sing-box ====
mkdir -p /etc/sing-box
cd /etc/sing-box || exit 1
echo "[INFO] 下载 sing-box 中..."

SB_URL=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
  | grep browser_download_url \
  | grep "linux-$ARCH_ID.tar.gz" \
  | cut -d '"' -f 4 | head -n1)

if [ -z "$SB_URL" ]; then
  echo "❌ 未找到适合架构 $ARCH_ID 的下载链接"
  exit 1
fi

curl -Lo sing-box.tar.gz "$SB_URL"
tar -xzf sing-box.tar.gz
cp sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# ==== 写入配置 ====
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "users": [
        {
          "username": "$USERNAME",
          "password": "$PASSWORD"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

# ==== 配置 OpenRC 服务 ====
if [ -f /etc/alpine-release ]; then
  echo "[INFO] 安装 OpenRC 服务..."
  cat > /etc/init.d/sing-box <<'RC'
#!/sbin/openrc-run
description="sing-box socks5 service"
command=/usr/local/bin/sing-box
command_args="run -c /etc/sing-box/config.json"
RC
  chmod +x /etc/init.d/sing-box
  rc-update add sing-box default
fi

# ==== 启动服务 ====
rc-service sing-box restart

# ==== 输出连接信息 ====
IP=$(curl -s https://api.ip.sb/ip || hostname -i | awk '{print $1}')
echo
echo "✅ 配置已完成，Socks5 启动中..."
echo "🌐 连接链接如下（推荐复制使用）："
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"