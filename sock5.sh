#!/bin/sh

set -e

LOG_FILE="/usr/local/sb/run.log"
SB_DIR="/usr/local/sb"
SB_BIN="$SB_DIR/sing-box"
SB_CONFIG="$SB_DIR/config.json"
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"

# 卸载逻辑
if [ "$1" = "uninstall" ]; then
    echo "[INFO] 开始卸载 sing-box 和相关文件..."
    pkill -f sing-box >/dev/null 2>&1 || true
    rm -rf "$SB_DIR" "$CLOUDFLARED_BIN"
    echo "[INFO] ✅ 卸载完成"
    exit 0
fi

# 检查变量
if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "[ERROR] ❌ 请设置环境变量 PORT、USERNAME 和 PASSWORD"
    echo "示例: PORT=16805 USERNAME=one PASSWORD=pass bash <(curl -Ls https://...)"
    exit 1
fi

# 安装依赖
echo "[INFO] 检测系统并安装依赖..."
if [ -f /etc/alpine-release ]; then
    apk update && apk add curl unzip >/dev/null
elif [ -f /etc/debian_version ] || grep -qi ubuntu /etc/os-release; then
    apt update && apt install -y curl unzip >/dev/null
fi

# 创建目录
mkdir -p "$SB_DIR"

# 下载 cloudflared
if [ ! -f "$CLOUDFLARED_BIN" ]; then
    echo "[INFO] 安装 cloudflared..."
    curl -Lo "$CLOUDFLARED_BIN" https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x "$CLOUDFLARED_BIN"
fi

# 下载 sing-box
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_ID=amd64 ;;
    aarch64) ARCH_ID=arm64 ;;
    *) echo "❌ 暂不支持架构: $ARCH"; exit 1 ;;
esac

SB_URL=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep browser_download_url | grep "linux-$ARCH_ID.zip" | cut -d '"' -f 4 | head -n1)

echo "[INFO] 下载 sing-box..."
curl -Lso /tmp/sb.zip "$SB_URL"
unzip -o /tmp/sb.zip -d /tmp/sb >/dev/null
cp /tmp/sb/sing-box "$SB_BIN"
chmod +x "$SB_BIN"

# 生成配置
cat > "$SB_CONFIG" <<EOF
{
  "log": {
    "level": "info",
    "output": "$LOG_FILE"
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

# 启动 socks5
echo "[INFO] 启动 socks5 代理..."
nohup "$SB_BIN" run -c "$SB_CONFIG" >> "$LOG_FILE" 2>&1 &

sleep 1
if pgrep -f "sing-box.*$PORT" >/dev/null; then
    echo "✅ socks5 已启动成功，端口: $PORT"
else
    echo "❌ socks5 启动失败，请检查日志: $LOG_FILE"
    exit 1
fi