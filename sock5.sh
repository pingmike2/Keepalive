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

# ==== 安装逻辑 ====

# 检查系统类型并安装依赖
if [ -f /etc/alpine-release ]; then
  echo "[INFO] 检测到 Alpine 系统，安装依赖中..."
  apk update && apk add curl tar
else
  echo "[INFO] 检测到非 Alpine 系统，尝试安装 curl 和 tar..."
  command -v apt && apt update && apt install -y curl tar || true
  command -v yum && yum install -y curl tar || true
fi

# 安装 sing-box
mkdir -p /etc/sing-box
cd /etc/sing-box || exit 1
echo "[INFO] 下载 sing-box 中..."
curl -L -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz
tar -xzf sing-box.tar.gz
cp sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# 写入配置文件
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

# 配置 OpenRC 服务
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

# 输出连接信息
IP=$(curl -s https://api.ip.sb/ip || hostname -i | awk '{print $1}')
echo "✅ 配置已完成，你可以手动运行以下命令启动 Socks5："
echo "   rc-service sing-box start"
echo
echo "🌐 连接链接如下（推荐复制使用）："
echo "socks5://$USERNAME:$PASSWORD@$IP:$PORT"