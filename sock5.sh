#!/bin/sh
set -e

# 环境变量配置
PORT=${PORT:-16805}
USERNAME=${USERNAME:-user}
PASSWORD=${PASSWORD:-pass}

WORK_DIR="/etc/sing-box"
BIN_DIR="/usr/local/bin"

# 卸载逻辑
if [ "$1" = "uninstall" ]; then
  echo "[卸载] 停止并移除 sing-box..."
  if [ -f /etc/init.d/sing-box ]; then
    rc-service sing-box stop
    rc-update del sing-box
    rm -f /etc/init.d/sing-box
  fi
  rm -rf "$WORK_DIR" "$BIN_DIR/sing-box"
  echo "✅ 卸载完成"
  exit 0
fi

# 安装依赖
if command -v apk >/dev/null; then
  apk update && apk add curl tar
elif command -v apt >/dev/null; then
  apt update && apt install -y curl tar
elif command -v yum >/dev/null; then
  yum install -y curl tar
else
  echo "❌ 不支持的系统"
  exit 1
fi

# 下载 sing-box 最新版本
mkdir -p "$WORK_DIR"
echo "[INFO] 获取 sing-box 最新 release..."
RELEASE_URL="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" \
  | grep browser_download_url \
  | grep linux-amd64.tar.gz \
  | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ 无法获取下载 URL"
  exit 1
fi

echo "[INFO] 下载 sing-box：$DOWNLOAD_URL"
curl -L -o /tmp/sb.tar.gz "$DOWNLOAD_URL"

# 解压并安装
tar -xzf /tmp/sb.tar.gz -C /tmp
cp /tmp/sing-box-*-linux-amd64/sing-box "$BIN_DIR/"
chmod +x "$BIN_DIR/sing-box"

# 写入配置
mkdir -p "$WORK_DIR"
cat > "$WORK_DIR/config.json" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "users": [{ "username": "$USERNAME", "password": "$PASSWORD" }]
    }
  ],
  "outbounds": [{ "type": "direct" }]
}
EOF

# 配置 OpenRC
if [ -f /etc/init.d/sing-box ] || [ -f /etc/alpine-release ]; then
  cat > /etc/init.d/sing-box <<'RC'
#!/sbin/openrc-run
description="sing-box socks5 service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
RC
  chmod +x /etc/init.d/sing-box
  rc-update add sing-box default
  rc-service sing-box restart
fi

# 输出运行信息
IP=$(curl -s https://api.ipify.org || hostname -i | awk '{print $1}')
echo
echo "✅ 安装完成，Socks5 正常启动！"
echo "🔗 复制并使用连接字符串："
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"