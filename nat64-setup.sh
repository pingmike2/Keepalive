#!/bin/bash

set -e

echo "🔧 开始配置 NAT64..."

# 1. 修改 /etc/systemd/resolved.conf
echo "📄 修改 /etc/systemd/resolved.conf..."
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=2602:fc59:b0:9e::64
FallbackDNS=2001:4860:4860::64
EOF

# 2. 创建 NAT64 路由 systemd 服务
echo "📄 创建 /etc/systemd/system/nat64-route.service..."
cat > /etc/systemd/system/nat64-route.service <<EOF
[Unit]
Description=Add NAT64 route
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip -6 route replace 2602:fc59:b0:64::/96 via 2602:fc59:b0:9e::64 dev venet0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 3. 应用服务并启动
echo "🔄 重载 systemd 守护进程..."
systemctl daemon-reexec
echo "📌 启用 NAT64 路由服务..."
systemctl enable nat64-route.service
systemctl start nat64-route.service

# 4. 验证路由是否生效
echo "✅ 当前 IPv6 路由表中包含以下 NAT64 条目："
ip -6 route show | grep 2602:fc59:b0:64::/96 || echo "⚠️ 未找到 NAT64 路由，可能未正确添加！"

# 5. 提示重启
echo -e "\n✅ NAT64 设置完成，可以执行以下命令进行重启验证："
echo "  reboot"