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
  command -v jq >/dev/null 2>&1 || {
    if [[ ${release} == "centos" ]]; then yum -y install jq
    elif [[ ${release} == "debian" ]]; then apt -y install jq
    elif [[ ${release} == "archlinux" ]]; then pacman -Sy jq --noconfirm
    fi
  }

  # 安装服务脚本
  install_service "server"
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
  cat >${CONF} <<-EOF
{"servers":[],"web_users":[{"username":"admin","password":"admin123"}]}
EOF
  cat >${CONF1} <<-EOF
PORT = 35601
HTTP_PORT = 8080
EOF
}

# ========== 启动/停止/重启 ==========
pid_server() { PID=$(pgrep -f "sergate"); }
pid_client() { PID=$(pgrep -f "status-client.py"); }

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

# ========== 菜单 ==========
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
  echo "  6. 查看日志"
  echo "  7. 切换客户端菜单"
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
    6) view_log "server" ;;
    7) menu_client ;;
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
  stop_server 2>/dev/null
  rm -rf "${SERVER_DIR}" "${WEB_DIR}"
  rm -f "/etc/init.d/starmonitor-server" "/usr/lib/systemd/system/starmonitor-server.service"
  echo -e "${Info} 服务端已卸载"
}

uninstall_client() {
  [[ ! -f "${CLIENT_DIR}/status-client.py" ]] && echo -e "${Error} 客户端未安装" && exit 1
  read -erp "确认卸载客户端？[y/N]: " yn
  [[ ${yn} != [Yy] ]] && return
  stop_client 2>/dev/null
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
