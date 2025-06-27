#!/bin/bash

INSTALL_DIR="/usr/local/sb"
CONFIG_FILE="$INSTALL_DIR/config.json"
BIN_FILE="$INSTALL_DIR/sing-box"
LOG_FILE="$INSTALL_DIR/run.log"
PID_FILE="$INSTALL_DIR/sb.pid"

if [[ "$1" == "uninstall" ]]; then
  echo "[INFO] 停止服务..."
  pkill -f "sing-box run" || true
  [[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE")" || true
  rm -rf "$INSTALL_DIR"
  echo "✅ 卸载完成。"
  exit 0
fi

if [[ -z "$PORT" || -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo >&2 "❌ 必须设置 PORT、USERNAME、PASSWORD 变量"
  echo >&2 "示例：PORT=16805 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls <GIST_URL>)"
  exit 1
fi

IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

echo "[INFO] 安装依赖..."
if command -v apk >/dev/null; then
  apk update && apk add curl tar unzip file
elif command -v apt >/dev/null; then
  apt update && apt install -y curl tar unzip file
elif command -v yum >/dev/null; then
  yum install -y curl tar unzip file
fi

mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

SB_VER=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
  | grep -o '"tag_name": *"[^"]*"' | head -n1 | cut -d '"' -f4)

if [[ -z "$SB_VER" ]]; then
  echo "❌ 获取版本号失败" >&2
  exit 1
fi

VERS="${SB_VER#v}"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_TYPE=amd64 ;;
  aarch64|arm64) ARCH_TYPE=arm64 ;;
  *) echo "❌ 不支持架构: $ARCH" >&2; exit 1 ;;
esac

URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VER}/sing-box-${VERS}-linux-${ARCH_TYPE}.tar.gz"
curl -Lo sb.tar.gz "$URL"

if ! file sb.tar.gz | grep -q 'gzip compressed'; then
  echo "❌ 下载异常，非 gzip 格式。" >&2
  head -n 20 sb.tar.gz
  exit 1
fi

tar -xzf sb.tar.gz --strip-components=1
chmod +x sing-box
rm -f sb.tar.gz

cat > "$CONFIG_FILE" <<EOF
{"log":{"level":"info"},"inbounds":[{"type":"socks","tag":"socks-in","listen":"0.0.0.0","listen_port":$PORT,"authentication":"password","users":[{"username":"$USERNAME","password":"$PASSWORD"}]}],"outbounds":[{"type":"direct"}]}
EOF

echo "[INFO] 启动 socks5 服务..."
nohup "$BIN_FILE" run -c "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
sleep 2

if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo
  echo "✅ Socks5 启动成功："
  echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"
else
  echo "❌ 服务未监听端口 $PORT，查看 $LOG_FILE"
  exit 1
fi