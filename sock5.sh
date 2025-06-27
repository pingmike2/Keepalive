#!/bin/bash

# socks5.sh - 安装或卸载 sing-box socks5 服务
# 使用方式：
# 安装：PORT=16805 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls https://your-url.com/socks5.sh)
# 卸载：bash <(curl -Ls https://your-url.com/socks5.sh) uninstall

INSTALL_DIR="/usr/local/sb"
CONFIG_FILE="$INSTALL_DIR/config.json"
BIN_FILE="$INSTALL_DIR/sing-box"
LOG_FILE="$INSTALL_DIR/run.log"
PID_FILE="$INSTALL_DIR/sb.pid"

# 卸载逻辑
if [[ "$1" == "uninstall" ]]; then
  echo "[INFO] 正在停止 socks5 服务..."
  pkill -f "sing-box run" >/dev/null 2>&1
  [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" >/dev/null 2>&1
  echo "[INFO] 删除文件..."
  rm -rf "$INSTALL_DIR"
  echo "✅ socks5 卸载完成。"
  exit 0
fi

# 检查变量
if [[ -z "$PORT" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "[ERROR] 必须设置 PORT、USERNAME、PASSWORD 变量，例如："
  echo "PORT=16805 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls https://your-url.com/socks5.sh)"
  exit 1
fi

# 获取公网 IP
IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

# 安装依赖（适配多种系统）
if command -v apk >/dev/null 2>&1; then
  apk update && apk add curl tar unzip
elif command -v apt >/dev/null 2>&1; then
  apt update && apt install -y curl tar unzip
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl tar unzip
fi

# 创建工作目录
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# 下载 sing-box（自动识别架构）
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TYPE=amd64 ;;
  aarch64 | arm64) ARCH_TYPE=arm64 ;;
  *) echo "[ERROR] 不支持的架构: $ARCH"; exit 1 ;;
esac

SB_VER=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep tag_name | cut -d '"' -f4)
curl -Lo sb.tar.gz "https://github.com/SagerNet/sing-box/releases/download/${SB_VER}/sing-box-${SB_VER}-linux-${ARCH_TYPE}.tar.gz"
tar -xzf sb.tar.gz --strip-components=1
chmod +x sing-box
rm -f sb.tar.gz

# 生成配置文件
cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [{
    "type": "socks",
    "tag": "socks-in",
    "listen": "0.0.0.0",
    "listen_port": $PORT,
    "authentication": "password",
    "users": [{
      "username": "$USERNAME",
      "password": "$PASSWORD"
    }]
  }],
  "outbounds": [{
    "type": "direct"
  }]
}
EOF

# 启动服务
echo "[INFO] 启动 socks5 服务..."
nohup "$BIN_FILE" run -c "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

# 检查是否启动成功
sleep 2
if pgrep -f "sing-box run" >/dev/null; then
  echo
  echo "✅ Socks5 启动成功："
  echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
else
  echo "❌ Socks5 启动失败，日志如下："
  tail -n 20 "$LOG_FILE"
  exit 1
fi