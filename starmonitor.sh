#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#  System Required: CentOS/Debian/Ubuntu/ArchLinux
#  Description: StarMonitor client + server
#  Version: v0.0.1
#  Author: oliverhy
#  Github: https://github.com/oliverhy/StarMonitor
#=================================================

sh_ver="0.0.1"
GITHUB="https://raw.githubusercontent.com/oliverhy/StarMonitor/master"

filepath=$(cd "$(dirname "$0")" || exit; pwd)
INSTALL_DIR="/usr/local/StarMonitor"
SERVER_DIR="${INSTALL_DIR}/server"
WEB_DIR="${INSTALL_DIR}/web"
CLIENT_DIR="${INSTALL_DIR}/client"
CONF="${SERVER_DIR}/config.json"
CONF1="${SERVER_DIR}/config.conf"
SERVER_LOG="/tmp/starmonitor_server.log"
CLIENT_LOG="/tmp/starmonitor_client.log"

Green='\033[32m' && Red='\033[31m' && RedBg='\033[41;37m' && Reset='\033[0m'
Info="${Green}[信息]${Reset}"
Error="${Red}[错误]${Reset}"
Tip="${Green}[注意]${Reset}"

is_remote() { [[ ! -f "${filepath}/starmonitor.sh" ]]; }

check_sys() {
  if [[ -f /etc/redhat-release ]]; then release="centos"
  elif grep -qi "debian\|ubuntu" /etc/issue 2>/dev/null; then release="debian"
  elif grep -qi "centos\|red hat" /etc/issue 2>/dev/null; then release="centos"
  elif grep -qi "Arch\|Manjaro" /etc/issue 2>/dev/null; then release="archlinux"
  elif grep -qi "debian\|ubuntu" /proc/version 2>/dev/null; then release="debian"
  elif grep -qi "centos\|red hat" /proc/version 2>/dev/null; then release="centos"
  else echo -e "${Error} StarMonitor 暂不支持该Linux发行版"; exit 1
  fi
}

install_deps() {
  local mode=$1
  if [[ ${release} == "centos" ]]; then
    yum makecache
    yum -y install unzip python3 >/dev/null 2>&1 || yum -y install python
    [[ ${mode} == "server" ]] && yum -y groupinstall "Development Tools"
  elif [[ ${release} == "debian" ]]; then
    apt -y update
    apt -y install unzip python3 >/dev/null 2>&1 || apt -y install python
    [[ ${mode} == "server" ]] && apt -y install build-essential
  elif [[ ${release} == "archlinux" ]]; then
    pacman -Sy python python-pip unzip --noconfirm
    [[ ${mode} == "server" ]] && pacman -Sy base-devel --noconfirm
  fi
  [[ ! -e /usr/bin/python ]] && ln -sf /usr/bin/python3 /usr/bin/python
}

install_jq() {
  if [[ ${release} == "centos" ]]; then yum -y install jq
  elif [[ ${release} == "debian" ]]; then apt -y install jq
  elif [[ ${release} == "archlinux" ]]; then pacman -Sy jq --noconfirm
  fi
}

# ========== 编译安装服务端 ==========
install_server() {
  if [[ -e "${SERVER_DIR}/sergate" ]]; then
    echo -e "${Error} StarMonitor 服务端已安装，请先卸载"; exit 1
  fi
  install_deps "server"

  if is_remote; then
    cd /tmp || exit 1
    wget -q --no-check-certificate "https://github.com/oliverhy/StarMonitor/archive/master.zip" -O starmonitor.zip
    unzip -q starmonitor.zip && rm -f starmonitor.zip
    cd StarMonitor-master/server || exit 1
    make
    [[ ! -f sergate ]] && echo -e "${Error} 编译失败" && exit 1
    mkdir -p "${SERVER_DIR}"
    mv sergate "${SERVER_DIR}/"
    mkdir -p "${WEB_DIR}"
    if [[ -d ../web ]]; then
      cp -r ../web/* "${WEB_DIR}/"
    else
      wget -q --no-check-certificate "https://github.com/cokemine/hotaru_theme/releases/latest/download/hotaru-theme.zip"
      unzip -q hotaru-theme.zip && mv hotaru-theme/* "${WEB_DIR}/" && rm -rf hotaru-theme hotaru-theme.zip
    fi
    rm -rf /tmp/StarMonitor-master
  else
    cd "${filepath}/server" || exit 1
    make
    [[ ! -f sergate ]] && echo -e "${Error} 编译失败" && exit 1
    mkdir -p "${SERVER_DIR}"
    mv sergate "${SERVER_DIR}/"
    mkdir -p "${WEB_DIR}"
    [[ -d "${filepath}/web" ]] && cp -r "${filepath}/web/"* "${WEB_DIR}/"
  fi

  # 安装 jq
  command -v jq >/dev/null 2>&1 || install_jq

  # 安装服务脚本
  install_service "server"
  mkdir -p "${WEB_DIR}/json"
  write_config
  echo -e "${Info} StarMonitor 服务端安装完成"
}

# ========== 安装客户端 ==========
install_client() {
  if [[ -e "${CLIENT_DIR}/status-client.py" ]]; then
    echo -e "${Error} StarMonitor 客户端已安装，请先卸载"; exit 1
  fi
  install_deps "client"
  mkdir -p "${CLIENT_DIR}"
  if is_remote; then
    wget -q --no-check-certificate "${GITHUB}/clients/status-client.py" -O "${CLIENT_DIR}/status-client.py"
  else
    cp "${filepath}/clients/status-client.py" "${CLIENT_DIR}/"
  fi
  [[ ! -f "${CLIENT_DIR}/status-client.py" ]] && echo -e "${Error} 客户端文件下载失败" && exit 1

  # 交互配置
  echo -e "${Info} 配置客户端连接信息"
  local srv="" port="" user="" pass=""
  read -erp "服务端 IP/域名: " srv
  [[ -z "${srv}" ]] && echo -e "${Error} 服务端地址不能为空" && exit 1
  read -erp "服务端端口（默认 35601）: " port
  [[ -z "${port}" ]] && port="35601"
  read -erp "节点用户名: " user
  [[ -z "${user}" ]] && echo -e "${Error} 用户名不能为空" && exit 1
  read -erp "节点密码: " pass
  [[ -z "${pass}" ]] && echo -e "${Error} 密码不能为空" && exit 1

  sed -i "s/SERVER = \".*\"/SERVER = \"${srv}\"/" "${CLIENT_DIR}/status-client.py"
  sed -i "s/PORT = .*/PORT = ${port}/" "${CLIENT_DIR}/status-client.py"
  sed -i "s/USER = \".*\"/USER = \"${user}\"/" "${CLIENT_DIR}/status-client.py"
  sed -i "s/PASSWORD = \".*\"/PASSWORD = \"${pass}\"/" "${CLIENT_DIR}/status-client.py"

  install_service "client"
  echo -e "${Info} StarMonitor 客户端安装完成"
}

# ========== 服务管理脚本 ==========
install_service() {
  local mode=$1
  local svc="starmonitor-${mode}"
  if [[ ${release} == "archlinux" ]]; then
    if is_remote; then
      wget -q --no-check-certificate "${GITHUB}/service/${svc}.service" -O "/usr/lib/systemd/system/${svc}.service"
    else
      cp "${filepath}/service/${svc}.service" "/usr/lib/systemd/system/"
    fi
    systemctl enable "${svc}.service"
  else
    if is_remote; then
      wget -q --no-check-certificate "${GITHUB}/service/starmonitor_${mode}_${release}" -O "/etc/init.d/${svc}"
    else
      cp "${filepath}/service/starmonitor_${mode}_${release}" "/etc/init.d/${svc}"
    fi
    chmod +x "/etc/init.d/${svc}"
    [[ ${release} == "centos" ]] && { chkconfig --add "${svc}"; chkconfig "${svc}" on; }
    [[ ${release} == "debian" ]] && update-rc.d -f "${svc}" defaults
  fi
  echo -e "${Info} ${svc} 服务脚本安装完成"
}

# ========== 配置文件 ==========
write_config() {
  mkdir -p "${SERVER_DIR}"

  echo -e "${Info} 配置 StarMonitor 服务端参数（直接回车使用默认值）"

  # 服务端监听端口
  local port="35601"
  read -erp "服务端监听端口（客户端连接用）[${port}]: " port_in
  [[ -n "${port_in}" ]] && port="${port_in}"

  # HTTP 仪表盘端口
  local http_port="8080"
  read -erp "仪表盘 HTTP 端口（浏览器访问用）[${http_port}]: " http_in
  [[ -n "${http_in}" ]] && http_port="${http_in}"

  # Web 登录用户名
  local web_user="admin"
  read -erp "Web 登录用户名[${web_user}]: " user_in
  [[ -n "${user_in}" ]] && web_user="${user_in}"

  # Web 登录密码
  local web_pass="admin123"
  read -erp "Web 登录密码[${web_pass}]: " pass_in
  [[ -n "${pass_in}" ]] && web_pass="${pass_in}"

  # 是否添加默认节点
  local add_node="n"
  read -erp "是否添加一个默认监控节点？[y/N]: " add_node
  if [[ "${add_node}" == [Yy] ]]; then
    local node_user="node01"
    local node_pass="password"
    local node_name="Server 01"
    local node_type="KVM"
    local node_loc="Hong Kong"
    local node_region="HK"
    read -erp "节点用户名[${node_user}]: " nu
    [[ -n "${nu}" ]] && node_user="${nu}"
    read -erp "节点密码[${node_pass}]: " np
    [[ -n "${np}" ]] && node_pass="${np}"
    read -erp "节点名称[${node_name}]: " nn
    [[ -n "${nn}" ]] && node_name="${nn}"
    read -erp "虚拟化类型[${node_type}]: " nt
    [[ -n "${nt}" ]] && node_type="${nt}"
    read -erp "节点位置[${node_loc}]: " nl
    [[ -n "${nl}" ]] && node_loc="${nl}"
    read -erp "节点地区代码[${node_region}]: " nr
    [[ -n "${nr}" ]] && node_region="${nr}"

    cat >${CONF} <<-EOF
{"servers":
 [
  {
   "username": "${node_user}",
   "password": "${node_pass}",
   "name": "${node_name}",
   "type": "${node_type}",
   "host": "",
   "location": "${node_loc}",
   "disabled": false,
   "region": "${node_region}"
  }
 ],
"web_users":
 [
  {
   "username": "${web_user}",
   "password": "${web_pass}"
  }
 ]
}
EOF
  else
    cat >${CONF} <<-EOF
{"servers":[],"web_users":[{"username":"${web_user}","password":"${web_pass}"}]}
EOF
  fi

  cat >${CONF1} <<-EOF
PORT = ${port}
HTTP_PORT = ${http_port}
EOF

  echo -e "${Info} 配置文件已生成：端口=${port}，仪表盘=${http_port}，Web用户=${web_user}"
}

# ========== 启动/停止/重启 ==========
pid_server() { PID=$(pgrep -f "sergate" | tr '\n' ' '); }
pid_client() { PID=$(pgrep -f "status-client.py" | tr '\n' ' '); }

do_service() {
  local action=$1 mode=$2
  local svc="starmonitor-${mode}"
  if [[ ${release} == "archlinux" ]]; then
    systemctl "${action}" "${svc}.service"
  else
    /etc/init.d/"${svc}" "${action}"
  fi
}

start_server() {
  [[ ! -f "${SERVER_DIR}/sergate" ]] && echo -e "${Error} 服务端未安装" && exit 1
  pid_server; [[ -n ${PID} ]] && echo -e "${Error} 服务端已在运行" && exit 1
  do_service "start" "server"
}

stop_server() {
  pid_server; [[ -z ${PID} ]] && echo -e "${Error} 服务端未运行" && exit 1
  do_service "stop" "server"
}

restart_server() {
  [[ ! -f "${SERVER_DIR}/sergate" ]] && echo -e "${Error} 服务端未安装" && exit 1
  do_service "restart" "server"
}

start_client() {
  [[ ! -f "${CLIENT_DIR}/status-client.py" ]] && echo -e "${Error} 客户端未安装" && exit 1
  pid_client; [[ -n ${PID} ]] && echo -e "${Error} 客户端已在运行" && exit 1
  do_service "start" "client"
}

stop_client() {
  pid_client; [[ -z ${PID} ]] && echo -e "${Error} 客户端未运行" && exit 1
  do_service "stop" "client"
}

restart_client() {
  [[ ! -f "${CLIENT_DIR}/status-client.py" ]] && echo -e "${Error} 客户端未安装" && exit 1
  do_service "restart" "client"
}

# ========== 节点管理 ==========
list_nodes() {
  [[ ! -f "${CONF}" ]] && echo -e "${Error} 配置文件不存在" && exit 1
  command -v jq >/dev/null 2>&1 || { echo -e "${Error} 需要 jq，请先安装"; exit 1; }
  local count=$(jq '.servers | length' "${CONF}")
  echo -e "${Info} 当前节点数: ${count}"
  jq -r '.servers[] | "  [\(.username)] \(.name) | \(.location) | \(.type) | \(if .disabled then "禁用" else "启用" end)"' "${CONF}" 2>/dev/null
  echo
  read -erp "按回车返回..." dummy
  menu_server
}

add_node() {
  [[ ! -f "${CONF}" ]] && echo -e "${Error} 配置文件不存在" && exit 1
  command -v jq >/dev/null 2>&1 || install_jq
  local user pass name type loc region
  read -erp "节点用户名: " user
  [[ -z "${user}" ]] && echo "已取消" && return
  read -erp "节点密码: " pass
  [[ -z "${pass}" ]] && pass="password"
  read -erp "节点名称: " name
  [[ -z "${name}" ]] && name="Server"
  read -erp "虚拟化类型: " type
  [[ -z "${type}" ]] && type="KVM"
  read -erp "节点位置: " loc
  [[ -z "${loc}" ]] && loc="Hong Kong"
  read -erp "地区代码: " region
  [[ -z "${region}" ]] && region="HK"

  local tmp=$(jq ".servers[.servers | length] |= . + {\"username\":\"${user}\",\"password\":\"${pass}\",\"name\":\"${name}\",\"type\":\"${type}\",\"host\":\"\",\"location\":\"${loc}\",\"disabled\":false,\"region\":\"${region}\"}" "${CONF}")
  echo "${tmp}" > "${CONF}"
  echo -e "${Info} 节点 ${user} 已添加"
  restart_server 2>/dev/null
}

del_node() {
  [[ ! -f "${CONF}" ]] && echo -e "${Error} 配置文件不存在" && exit 1
  list_nodes
  read -erp "请输入要删除的节点用户名: " user
  [[ -z "${user}" ]] && return
  local tmp=$(jq "del(.servers[] | select(.username == \"${user}\"))" "${CONF}")
  echo "${tmp}" > "${CONF}"
  echo -e "${Info} 节点 ${user} 已删除"
  restart_server 2>/dev/null
}

# ========== Caddy 配置 ==========
setup_caddy() {
  command -v caddy >/dev/null 2>&1 || {
    read -erp "Caddy 未安装，是否安装？[y/N]: " yn
    [[ ${yn} != [Yy] ]] && return
    if [[ ${release} == "centos" ]]; then yum -y install caddy
    elif [[ ${release} == "debian" ]]; then apt -y install caddy
    elif [[ ${release} == "archlinux" ]]; then pacman -Sy caddy --noconfirm
    fi
    systemctl enable caddy
  }

  local http_port=$(grep "HTTP_PORT" "${CONF1}" 2>/dev/null | awk '{print $3}')
  [[ -z "${http_port}" ]] && http_port="8080"

  echo "  1. HTTP 模式（IP+端口）"
  echo "  2. HTTPS 模式（域名+自动证书）"
  read -erp "请选择 [1-2]: " mode
  if [[ ${mode} == "2" ]]; then
    read -erp "请输入域名: " domain
    [[ -z "${domain}" ]] && echo "已取消" && return
    cat >/etc/caddy/Caddyfile <<-EOF
${domain} {
  reverse_proxy localhost:${http_port}
  encode gzip
}
EOF
  else
    local addr
    read -erp "监听地址（留空=所有接口）: " addr
    local listen=":80"
    [[ -n "${addr}" ]] && listen="http://${addr}:80"
    cat >/etc/caddy/Caddyfile <<-EOF
${listen} {
  reverse_proxy localhost:${http_port}
  encode gzip
}
EOF
  fi
  systemctl restart caddy
  echo -e "${Info} Caddy 配置完成"
}
menu_server() {
  clear
  echo "————————————————————————————"
  echo "  StarMonitor 服务端管理 v${sh_ver}"
  echo "  https://github.com/oliverhy/StarMonitor"
  echo "————————————————————————————"
  echo "  1. 安装服务端"
  echo "  2. 卸载服务端"
  echo "  3. 启动服务端"
  echo "  4. 停止服务端"
  echo "  5. 重启服务端"
  echo "  6. 查看节点列表"
  echo "  7. 添加节点"
  echo "  8. 删除节点"
  echo "  9. 配置 Caddy 反代"
  echo " 10. 查看日志"
  echo " 11. 切换客户端菜单"
  echo "————————————————————————————"
  if [[ -f "${SERVER_DIR}/sergate" ]]; then
    pid_server
    if [[ -n ${PID} ]]; then echo -e "  状态: ${Green}已安装${Reset} | ${Green}运行中${Reset}"
    else echo -e "  状态: ${Green}已安装${Reset} | ${Red}未运行${Reset}"; fi
  else echo -e "  状态: ${Red}未安装${Reset}"
  fi
  echo
  read -erp " 请输入数字: " num
  case ${num} in
    1) install_server ;;
    2) uninstall_server ;;
    3) start_server ;;
    4) stop_server ;;
    5) restart_server ;;
    6) list_nodes ;;
    7) add_node ;;
    8) del_node ;;
    9) setup_caddy ;;
    10) view_log "server" ;;
    11) menu_client ;;
    *) echo "输入错误" && sleep 1 && menu_server ;;
  esac
}

menu_client() {
  clear
  echo "————————————————————————————"
  echo "  StarMonitor 客户端管理 v${sh_ver}"
  echo "  https://github.com/oliverhy/StarMonitor"
  echo "————————————————————————————"
  echo "  1. 安装客户端"
  echo "  2. 卸载客户端"
  echo "  3. 启动客户端"
  echo "  4. 停止客户端"
  echo "  5. 重启客户端"
  echo "  6. 查看日志"
  echo "  7. 切换服务端菜单"
  echo "————————————————————————————"
  if [[ -f "${CLIENT_DIR}/status-client.py" ]]; then
    pid_client
    if [[ -n ${PID} ]]; then echo -e "  状态: ${Green}已安装${Reset} | ${Green}运行中${Reset}"
    else echo -e "  状态: ${Green}已安装${Reset} | ${Red}未运行${Reset}"; fi
  else echo -e "  状态: ${Red}未安装${Reset}"
  fi
  echo
  read -erp " 请输入数字: " num
  case ${num} in
    1) install_client ;;
    2) uninstall_client ;;
    3) start_client ;;
    4) stop_client ;;
    5) restart_client ;;
    6) view_log "client" ;;
    7) menu_server ;;
    *) echo "输入错误" && sleep 1 && menu_client ;;
  esac
}

uninstall_server() {
  [[ ! -f "${SERVER_DIR}/sergate" ]] && echo -e "${Error} 服务端未安装" && exit 1
  read -erp "确认卸载服务端？[y/N]: " yn
  [[ ${yn} != [Yy] ]] && return
  pid_server
  [[ -n ${PID} ]] && do_service "stop" "server"
  rm -rf "${SERVER_DIR}" "${WEB_DIR}"
  rm -f "/etc/init.d/starmonitor-server" "/usr/lib/systemd/system/starmonitor-server.service"
  echo -e "${Info} 服务端已卸载"
}

uninstall_client() {
  [[ ! -f "${CLIENT_DIR}/status-client.py" ]] && echo -e "${Error} 客户端未安装" && exit 1
  read -erp "确认卸载客户端？[y/N]: " yn
  [[ ${yn} != [Yy] ]] && return
  pid_client
  [[ -n ${PID} ]] && do_service "stop" "client"
  rm -rf "${CLIENT_DIR}"
  rm -f "/etc/init.d/starmonitor-client" "/usr/lib/systemd/system/starmonitor-client.service"
  echo -e "${Info} 客户端已卸载"
}

view_log() {
  local log=${SERVER_LOG}
  [[ $1 == "client" ]] && log=${CLIENT_LOG}
  [[ ! -f ${log} ]] && echo -e "${Error} 日志文件不存在" && exit 1
  tail -f "${log}"
}

# ========== 入口 ==========
check_sys
action=$1
case ${action} in
  s|server) menu_server ;;
  c|client) menu_client ;;
  *) menu_client ;;
esac
