#!/bin/sh

# 默认配置（如未传入环境变量则使用这些）
PORT=${PORT:-10808}
USERNAME=${USERNAME:-"user"}
PASSWORD=${PASSWORD:-"pass"}

# 检查系统类型
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

# 启动服务
if [ -f /etc/alpine-release ]; then
  echo "[INFO] 使用 OpenRC 启动 sing-box..."
  cat > /etc/init.d/sing-box <<'RC'
#!/sbin/openrc-run
description="sing-box socks5 service"
command=/usr/local/bin/sing-box
command_args="run -c /etc/sing-box/config.json"
RC
  chmod +x /etc/init.d/sing-box
  rc-update add sing-box
  rc-service sing-box restart
else
  echo "[INFO] 使用 systemd 启动 sing-box..."
  cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Socks5 Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable sing-box
  systemctl restart sing-box
fi

# 输出提示
echo "✅ Socks5 启动成功"
echo "📌 IP地址：你的服务器公网 IP"
echo "📌 端口：$PORT"
echo "📌 用户名：$USERNAME"
echo "📌 密码：$PASSWORD"