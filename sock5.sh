#!/bin/sh

# ==== 可通过环境变量自定义 ====
PORT=${PORT:-16805}
USERNAME=${USERNAME:-"user"}
PASSWORD=${PASSWORD:-"pass"}

BIN_DIR="/usr/local/bin"
WORK_DIR="/etc/sing-box"
CONFIG_FILE="$WORK_DIR/config.json"
SB_RELEASE="https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz"

# ==== 卸载逻辑 ====
if [ "$1" = "uninstall" ]; then
  echo "[卸载] 停止并移除 sing-box..."
  if [ -f /etc/init.d/sing-box ]; then
    rc-service sing-box stop
    rc-update del sing-box
    rm -f /etc/init.d/sing-box
  fi
  rm -rf "$WORK_DIR"
  rm -f "$BIN_DIR/sing-box"
  echo "✅ 卸载完成"
  exit 0
fi

# ==== 安装依赖 ====
if [ -f /etc/alpine-release ]; then
  echo "[INFO] 检测到 Alpine 系统，安装依赖中..."
  apk update && apk add curl tar
else
  echo "[INFO] 检测到非 Alpine 系统，安装 curl 和 tar..."
  command -v apt && apt update && apt install -y curl tar || true
  command -v yum && yum install -y curl tar || true
fi

# ==== 下载并安装 sing-box ====
echo "[INFO] 下载 sing-box 中..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || exit 1
curl -L -o sb.tar.gz "$SB_RELEASE"
tar -xzf sb.tar.gz
# 自动查找解压目录
SB_EXTRACTED=$(tar -tzf sb.tar.gz | head -1 | cut -f1 -d"/")
cp "${SB_EXTRACTED}/sing-box" "$BIN_DIR/"
chmod +x "$BIN_DIR/sing-box"

# ==== 写入配置 ====
cat > "$CONFIG_FILE" <<EOF
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
  echo "[INFO] 配置 OpenRC 服务..."
  cat > /etc/init.d/sing-box <<'RC'
#!/sbin/openrc-run
description="sing-box socks5 service"
command=/usr/local/bin/sing-box
command_args="run -c /etc/sing-box/config.json"
RC
  chmod +x /etc/init.d/sing-box
  rc-update add sing-box default
  rc-service sing-box restart
fi

# ==== 获取真实 IP ====
IP=$(curl -s https://api.ipify.org || hostname -i | awk '{print $1}')

echo
echo "✅ 配置完成，Socks5 已启动"
echo "🌐 连接链接如下（推荐复制使用）："
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"