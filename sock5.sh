#!/bin/bash

# sing-box socks5 安装/卸载脚本
# 使用方式：
# 安装：PORT=16805 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls https://raw.githubusercontent.com/pingmike2/Keepalive/main/sock5.sh)
# 卸载：bash <(curl -Ls https://raw.githubusercontent.com/pingmike2/Keepalive/main/sock5.sh) uninstall

INSTALL_DIR="/usr/local/sb"
CONFIG_FILE="$INSTALL_DIR/config.json"
BIN_FILE="$INSTALL_DIR/sing-box"
LOG_FILE="$INSTALL_DIR/run.log"
PID_FILE="$INSTALL_DIR/sb.pid"

# ========== 卸载逻辑 ==========
if [[ "$1" == "uninstall" ]]; then
  echo "[INFO] 停止 socks5 服务..."
  pkill -f "sing-box run" >/dev/null 2>&1
  [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" >/dev/null 2>&1
  echo "[INFO] 删除文件..."
  rm -rf "$INSTALL_DIR"
  echo "✅ socks5 卸载完成。"
  exit 0
fi

# ========== 环境变量检查 ==========
if [[ -z "$PORT" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "[ERROR] 必须设置 PORT、USERNAME、PASSWORD 变量，例如："
  echo "PORT=16805 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls https://raw.githubusercontent.com/pingmike2/Keepalive/main/sock5.sh)"
  exit 1
fi

# ========== 获取公网 IP ==========
IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

# ========== 安装依赖 ==========
echo "[INFO] 安装依赖..."
if command -v apk >/dev/null 2>&1; then
  apk update && apk add curl tar unzip file
elif command -v apt >/dev/null 2>&1; then
  apt update && apt install -y curl tar unzip file
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl tar unzip file
fi

# ========== 下载 sing-box ==========
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TYPE=amd64 ;;
  aarch64 | arm64) ARCH_TYPE=arm64 ;;
  *) echo "[ERROR] 不支持的架构: $ARCH"; exit 1 ;;
esac

SB_VER=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -n1 | cut -d '"' -f4)
if [[ -z "$SB_VER" ]]; then
  echo "[ERROR] 获取 sing-box 版本失败，可能是网络问题。"
  exit 1
fi

VERS="${SB_VER#v}"
URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VER}/sing-box-${VERS}-linux-${ARCH_TYPE}.tar.gz"

echo "[INFO] 下载 sing-box: $URL"
curl -Lo sb.tar.gz "$URL"

# 验证 tar.gz 是否有效 gzip 格式
if ! file sb.tar.gz | grep -q 'gzip compressed'; then
  echo "❌ 下载失败，文件不是有效的 gzip 格式。内容如下："
  head -n 10 sb.tar.gz
  exit 1
fi

tar -xzf sb.tar.gz --strip-components=1
chmod +x sing-box
rm -f sb.tar.gz

# ========== 生成配置文件 ==========
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

# ========== 启动服务 ==========
echo "[INFO] 启动 socks5 服务..."
nohup "$BIN_FILE" run -c "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
sleep 2

# ========== 检查是否监听成功 ==========
if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1 || netstat -tnlp | grep ":$PORT" >/dev/null 2>&1; then
  echo
  echo "✅ Socks5 启动成功："
  echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
else
  echo "❌ socks5 启动失败，请查看日志：$LOG_FILE"
  tail -n 20 "$LOG_FILE"
  exit 1
fi