#!/bin/bash

# 配色函数
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
purple() { echo -e "\033[35m$1\033[0m"; }

# 变量
work_dir="/usr/local/sb"
server_name="sing-box"
PORT=16805
USERNAME="oneforall"
PASSWORD="allforone"

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && red "请使用 root 用户运行此脚本！" && exit 1

# 获取真实 IP（优先返回非 Cloudflare 的 IPv4，否则返回 IPv6）
get_realip() {
  ip=$(curl -s --max-time 2 ipv4.ip.sb)
  if [ -z "$ip" ]; then
    ipv6=$(curl -s --max-time 1 ipv6.ip.sb)
    echo "[$ipv6]"
  else
    if curl -s http://ipinfo.io/org | grep -qE 'Cloudflare|UnReal|AEZA|Andrei'; then
      ipv6=$(curl -s --max-time 1 ipv6.ip.sb)
      echo "[$ipv6]"
    else
      echo "$ip"
    fi
  fi
}

# 下载并安装 sing-box 和 cloudflared
install_singbox() {
  clear
  purple "正在安装 sing-box 和 cloudflared 中，请稍后..."

  ARCH_RAW=$(uname -m)
  case "$ARCH_RAW" in
    x86_64) ARCH="amd64" ;;
    i386 | i686 | x86) ARCH="386" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    s390x) ARCH="s390x" ;;
    *) red "不支持的架构: $ARCH_RAW" && exit 1 ;;
  esac

  mkdir -p "$work_dir" && chmod 777 "$work_dir"
  curl -sLo "$work_dir/sing-box" "https://$ARCH.ssss.nyc.mn/sbx"
  curl -sLo "$work_dir/argo" "https://$ARCH.ssss.nyc.mn/bot"
  chmod +x "$work_dir/sing-box" "$work_dir/argo"

  green "✅ 安装完成"
}

# 生成 sing-box 配置文件
generate_config() {
  cat > "$work_dir/config.json" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "socks",
      "listen": "0.0.0.0",
      "listen_port": $PORT,
      "sniff": true,
      "set_system_proxy": false,
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
}

# 启动 socks5 服务
start_singbox() {
  generate_config
  nohup "$work_dir/sing-box" run -c "$work_dir/config.json" > "$work_dir/run.log" 2>&1 &
  sleep 1
  if pgrep -f "$work_dir/sing-box" > /dev/null; then
    green "✅ socks5 服务已启动："
    echo -e "socks5://$USERNAME:$PASSWORD@$(get_realip):$PORT"
  else
    red "❌ socks5 启动失败，请检查日志 $work_dir/run.log"
  fi
}

# 一键卸载
uninstall() {
  read -rp "是否确认卸载 sing-box？(y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    pkill -f "$work_dir/sing-box"
    rm -rf "$work_dir"
    green "✅ 已卸载 sing-box"
  else
    yellow "取消卸载"
  fi
}

# 主菜单
main_menu() {
  echo -e "=============================="
  echo -e "🎯 socks5 一键安装脚本"
  echo -e "📌 当前端口: $PORT"
  echo -e "=============================="
  echo -e "1. 安装并启动 socks5"
  echo -e "2. 卸载 sing-box"
  echo -e "0. 退出"
  echo -e "=============================="
  read -rp "请输入选项: " menu

  case "$menu" in
    1)
      install_singbox
      start_singbox
      ;;
    2)
      uninstall
      ;;
    0)
      exit 0
      ;;
    *)
      red "无效的选项"
      ;;
  esac
}

main_menu