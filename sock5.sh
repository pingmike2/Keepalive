#!/bin/sh

# 自定义配置变量（可修改）
PORT=10808
USERNAME="youruser"
PASSWORD="yourpass"

# 检查系统类型（支持 Alpine / Debian / Ubuntu）
if [ -f /etc/alpine-release ]; then
  echo "检测到 Alpine 系统，安装依赖..."
  apk update
  apk add curl tar
else
  echo "检测到非 Alpine 系统，尝试使用 apt/yum 安装依赖..."
  command -v apt && apt update && apt install -y curl tar || true
  command -v yum && yum install -y curl tar || true
fi

# 安装 sing-box（Linux x86_64 架构）
mkdir -p /etc/sing-box
cd /etc/sing-box || exit 1

echo "下载并解压 sing-box..."
curl -L -o sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-linux-amd64.tar.gz
tar -xzf sing-box.tar.gz
cp sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

# 创建配置文件
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

# 创建 rc-service 或 systemd 启动方式
if [ -f /etc/alpine-release ]; then
  echo "配置 Alpine rc-service ..."
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
  echo "配置 systemd 服务 ..."
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

echo "✅ Socks5 启动成功"
echo "地址: 你的服务器IP"
echo "端口: $PORT"
echo "用户名: $USERNAME"
echo "密码: $PASSWORD"
