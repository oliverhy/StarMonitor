# StarMonitor

云探针、多服务器探针、云监控 — 基于 ServerStatus-Hotaru，内嵌 Web 登录认证与仪表盘。

## 特性

- 服务端客户端脚本支持系统：Centos 7、Debian 8、Ubuntu 15.10 及以上、ArchLinux
- Python 客户端：支持 Python 2.7+
- Go 客户端：https://github.com/cokemine/ServerStatus-goclient
- 流量计算：支持 vnStat 按月统计或重启清零
- **内嵌 Web 仪表盘**：无需额外前端，sergate 自带 HTTP 服务器
- **用户登录认证**：配置 `web_users` 账号密码，Token 鉴权
- **Caddy HTTPS 支持**：安装时可选择域名自动申请 Let's Encrypt 证书

## 安装方法

### 一键安装

```bash
bash <(curl -s https://raw.githubusercontent.com/oliverhy/StarMonitor/master/status.sh) s
```

安装过程中会提示：
1. 服务端监听端口（默认 35601，客户端连接用）
2. 仪表盘 HTTP 端口（默认 8080，浏览器访问用）
3. Web 登录用户名/密码
4. Caddy 配置方式：HTTP（IP+端口）或 HTTPS（域名，自动申请证书）

客户端：

```bash
bash <(curl -s https://raw.githubusercontent.com/oliverhy/StarMonitor/master/status.sh) c
```

### 手动安装服务端

```bash
mkdir -p /usr/local/ServerStatus/server
apt install wget unzip curl vim build-essential
cd /tmp
wget https://github.com/oliverhy/StarMonitor/archive/master.zip
unzip master.zip
cd ./StarMonitor-master/server
make
chmod +x sergate
mv sergate /usr/local/ServerStatus/server
vim /usr/local/ServerStatus/server/config.json  # 配置节点和 web_users
nohup ./sergate --config=config.json --web-dir=/usr/local/ServerStatus/web --port=35601 --http-port=8080 > /tmp/serverstatus_server.log 2>&1 &
```

浏览器访问 `http://IP:8080` 即可看到登录页。

## 配置文件

```json
{
  "servers": [
    {
      "username": "s01",
      "password": "password",
      "name": "Server 01",
      "type": "KVM",
      "host": "",
      "location": "Hong Kong",
      "disabled": false,
      "region": "HK"
    }
  ],
  "web_users": [
    {
      "username": "admin",
      "password": "admin123"
    }
  ]
}
```

`web_users` 为 Web 登录账号，支持多个用户。

## 命令行参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-p, --port` | 35601 | 服务端监听端口（客户端连接） |
| `--http-port` | 8080 | 内嵌 HTTP 仪表盘端口 |
| `-d, --web-dir` | ../web/ | Web 目录 |
| `-c, --config` | config.json | 配置文件路径 |
| `-b, --bind` | 所有地址 | 绑定地址 |
| `-v, --verbose` | 关闭 | 详细日志 |

## 效果演示

浏览器打开 `http://IP:8080` → 登录页 → 仪表盘，实时查看所有服务器状态（CPU、内存、硬盘、流量、运行时间）。

## 相关开源项目

- ServerStatus-Hotaru：https://github.com/cokemine/ServerStatus-Hotaru MIT License
- ServerStatus-Toyo：https://github.com/ToyoDAdoubiBackup/ServerStatus-Toyo MIT License
- ServerStatus：https://github.com/BotoX/ServerStatus WTFPL License
- NodeStatus：https://github.com/cokemine/nodestatus

## 感谢

- i18n-iso-countries, jq, caddy, twemoji
