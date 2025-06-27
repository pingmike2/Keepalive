#!/bin/sh

set -e

# ========== 基础变量 ==========
SB_DIR="/usr/local/sb"
SB_BIN="/usr/local/bin/sing-box"
SB_LOG="$SB_DIR/run.log"
CF_BIN="/usr/local/bin/cloudflared"
ARCH=""
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# ========== 接收变量 ==========
PORT="${PORT:-1080}"
USERNAME="${USERNAME:-user}"
PASSWORD="${PASSWORD:-pass}"

# ========== 检查是否卸载 ==========
if [ "$1" = "uninstall" ]; then
    echo "[INFO] 停止并卸载服务..."
    rc-service sing-box stop 2>/dev/null || systemctl stop sing-box 2>/dev/null || true
    rc-update del sing-box default 2>/dev/null || systemctl disable sing-box 2>/dev/null || true
    rm -rf /etc/init.d/sing-box /etc/systemd/system/sing-box.service \
           $SB_BIN $SB_DIR $CF_BIN
    echo "✅ 已卸载完毕"
    exit 0
fi

# ========== 安装依赖 ==========
install_deps() {
    echo "[INFO] 检测系统并安装 curl tar unzip..."
    if command -v apk >/dev/null 2>&1; then
        apk update && apk add curl tar unzip
    elif command -v apt >/dev/null 2>&1; then
        apt update -y && apt install -y curl tar unzip
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl tar unzip
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl tar unzip
    else
        echo "[ERROR] 不支持的 Linux 系统，请手动安装 curl tar unzip"
        exit 1
    fi
}

# ========== 检测架构 ==========
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7*) ARCH="armv7" ;;
        i386) ARCH="386" ;;
        *) echo "[ERROR] 暂不支持该架构: $ARCH" && exit 1 ;;
    esac
}

# ========== 下载并安装 sing-box ==========
install_singbox() {
    echo "[INFO] 下载 sing-box 中..."
    mkdir -p "$SB_DIR"
    cd "$SB_DIR"

    VER=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep tag_name | cut -d '"' -f 4)
    FILE="sing-box-${VER}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/${VER}/${FILE}"

    curl -LO "$URL"
    tar -xf "$FILE"
    cp -f sing-box-${VER}-linux-${ARCH}/sing-box "$SB_BIN"
    chmod +x "$SB_BIN"
}

# ========== 下载并安装 cloudflared ==========
install_cloudflared() {
    echo "[INFO] 下载 cloudflared 中..."
    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
    curl -Lo "$CF_BIN" "$URL"
    chmod +x "$CF_BIN"
}

# ========== 写入配置 ==========
write_config() {
    mkdir -p "$SB_DIR"
    cat > "$SB_DIR/config.json" <<EOF
{
  "log": {
    "level": "info",
    "output": "$SB_LOG"
  },
  "inbounds": [{
    "type": "socks",
    "listen": "127.0.0.1",
    "listen_port": $PORT,
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
}

# ========== 写入服务 ==========
write_service() {
    if command -v rc-update >/dev/null 2>&1; then
        cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
command="$SB_BIN"
command_args="run -c $SB_DIR/config.json"
pidfile="$SB_DIR/sing-box.pid"
EOF
        chmod +x /etc/init.d/sing-box
        rc-update add sing-box default
    elif command -v systemctl >/dev/null 2>&1; then
        cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Socks5 Service
After=network.target

[Service]
ExecStart=$SB_BIN run -c $SB_DIR/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reexec
        systemctl enable sing-box
    else
        echo "[ERROR] 无法设置开机启动，请手动添加"
    fi
}

# ========== 启动服务 ==========
start_service() {
    echo "[INFO] 启动 Socks5 服务..."
    if command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box restart
    else
        systemctl restart sing-box
    fi
}

# ========== 主执行流程 ==========
install_deps
detect_arch
install_singbox
install_cloudflared
write_config
write_service
start_service

IP=$(curl -s https://ip.sb || echo "<your-server-ip>")
echo
echo "✅ 配置已完成，Socks5 启动中..."
echo "🌐 连接链接如下（推荐复制使用）："
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"