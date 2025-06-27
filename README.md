# 项目说明
各种保活项目

## Serv00保活直接用老王的项目
- 老王[仓库地址](https://github.com/eooce/Sing-box)  
> 特点：全自动保活

----

## VPS版一键无交互脚本Socks5
socks5
```
PORT=25410 USERNAME=oneforall PASSWORD=allforone bash <(curl -Ls https://raw.githubusercontent.com/pingmike2/Keepalive/main/sock5.sh)
```

卸载
```
bash <(curl -Ls https://raw.githubusercontent.com/pingmike2/Keepalive/main/sock5.sh) uninstall
```
查看配置
```
cat /usr/local/sb/config.json
```
## 测试socks5是否通畅
运行以下命令，若正确返回服务器ip则节点通畅
```
curl ip.sb --socks5 用户名:密码@localhost:端口
```
