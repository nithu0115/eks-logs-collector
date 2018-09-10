#!/bin/bash
# Author: Nithish Kumar
# - Collects Docker daemon and Amazon EKS daemon set information on Amazon Linux,
#   Redhat 7, Debian 8.
# - Collects general operating system logs.
# - Optional ability to enable debug mode for the Docker daemon

export LANG="C"
export LC_ALL="C"

# Global options
PROGRAM_NAME="$(basename "$0" .sh)" 
COLLECT_DIR="/tmp/${PROGRAM_NAME}"
DAYS_7=$(date -d "-7 days" '+%Y-%m-%d %H:%M')
INSTANCE_ID=""
INIT_TYPE=""
PACKAGE_TYPE=""

help()
{
  echo "USAGE: ${PROGRAM_NAME} --mode=collect|enable_debug"
  echo "       ${PROGRAM_NAME} --help"
  echo ""
  echo "OPTIONS:"
  echo "     --mode  Sets the desired mode of the script. For more information,"
  echo "             see the MODES section."
  echo "     --help  Show this help message."
  echo ""
  echo "MODES:"
  echo "     collect       Gathers basic operating system, Docker daemon, and Amazon"
  echo "                 EKS related config files and logs. This is the default mode."
  echo "     enable_debug  Enables debug mode for the Docker daemon"
}

systemd_check()
{
  if [[ -L "/sbin/init" ]]; then
      INIT_TYPE="systemd"
    else
      INIT_TYPE="other"
    fi
}

parse_options() {
  local count="$#"

  for i in $(seq "${count}"); do
    eval arg="\$$i"
    param="$(echo "${arg}" | awk -F '=' '{print $1}' | sed -e 's|--||')"
    val="$(echo "${arg}" | awk -F '=' '{print $2}')"

    case "${param}" in
      mode)
        eval "${param}"="${val}"
        ;;
      help)
        help && exit 0
        ;;
      *)
        echo "Command not found: '--$param'"
        help && exit 1
        ;;
    esac
  done
}

ok()
{
  echo
}

info()
{
  echo "$*"
}

try() {
  local action=$*
  echo -n "Trying to $action... "
}

warning() {
  local reason=$*
  echo "Warning: $reason "
}

fail() {
  echo "failed"
}

failed() {
  local reason=$*
  echo "failed: $reason"
}

die()
{
  echo "ERROR: $*.. exiting..."
  exit 1
}

is_root()
{
  try "check if the script is running as root"

  if [[ "$(id -u)" -ne 0 ]]; then
    die "This script must be run as root!"
  fi

  ok
}

create_directories() {
    mkdir -p "${COLLECT_DIR}"/{kernel,system,eks,docker,storage,var_log}
}

instance_metadata() {
  try "resolve instance-id"

  local curl_bin
  curl_bin="$(command -v curl)"

  if [[ -z "${curl_bin}" ]]; then
      warning "Curl not found, please install curl. You can still view the logs in the collect folder."
      INSTANCE_ID=$(hostname)
      echo "${INSTANCE_ID}" > "${COLLECT_DIR}"/system/instance-id.txt
    else
      INSTANCE_ID=$(curl --max-time 3 -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
      echo "${INSTANCE_ID}" > "${COLLECT_DIR}"/system/instance-id.txt
  fi

  ok
}

is_diskfull()
{
  try "check disk space usage"

  local threshold
  local result
  threshold=1500000
  result=$(df / | grep -v "Filesystem" | awk '{ print $4 }')

  if [[ "${result}" -lt "${threshold}" ]]; then
    die "Less than $((threshold>>10))MB, please ensure adequate disk space to collect and store the log files."
  fi

  ok
}

cleanup()
{
  rm -rf "${COLLECT_DIR}" >/dev/null 2>&1
}

init() {
  is_root
  create_directories
  instance_metadata
  systemd_check
}

collect() {
  init
  is_diskfull
  get_common_logs
  get_kernel_logs
  get_mounts_info
  get_selinux_info
  get_iptables_info
  get_pkgtype
  get_pkglist
  get_system_services
  get_docker_info
  get_eks_logs_and_configfiles
  get_containers_info
  get_docker_logs
}

enable_debug() {
  init
  enable_docker_debug
}

pack()
{
  try "archive gathered log information"

  local TAR_BIN
  TAR_BIN="$(command -v tar)"

  if [[ -z "${TAR_BIN}" ]]; then
      warning "TAR archiver not found, please install a TAR archiver to create the collection archive. You can still view the logs in the collect folder."
    else
      ${TAR_BIN} --create --verbose --gzip --file "${HOME}"/ekslogsbundle_"${INSTANCE_ID}"_"$(date --utc +%Y-%m-%d_%H%M-%Z)".tar.gz --directory="${COLLECT_DIR}" . > /dev/null 2>&1
  fi

  ok
}

get_mounts_info()
{
  try "get mount points and volume information"
  mount > "${COLLECT_DIR}"/storage/mounts.txt
  echo >> "${COLLECT_DIR}"/storage/mounts.txt
  df -h >> "${COLLECT_DIR}"/storage/mounts.txt

  if [[ -e /sbin/lvs ]]; then
    lvs > "${COLLECT_DIR}"/storage/lvs.txt
    pvs > "${COLLECT_DIR}"/storage/pvs.txt
    vgs > "${COLLECT_DIR}"/storage/vgs.txt
  fi

  ok
}

get_selinux_info()
{
  try "check SELinux status"

  local GETENFORCE_BIN
  local SELINUX_STATUS
  GETENFORCE_BIN="$(command -v getenforce)"
  SELINUX_STATUS="$(${GETENFORCE_BIN})" 2>/dev/null
  
  if [[ -z "${SELINUX_STATUS}" ]]; then
      echo -e "SELinux mode:\n\t Not installed" > "${COLLECT_DIR}"/system/selinux.txt
    else
      echo -e "SELinux mode:\n\t ${SELINUX_STATUS}" > "${COLLECT_DIR}"/system/selinux.txt
  fi

  ok
}

get_iptables_info()
{
  try "get iptables list"

  /sbin/iptables -nvL -t filter > "${COLLECT_DIR}"/system/iptables-filter.txt
  /sbin/iptables -nvL -t nat  > "${COLLECT_DIR}"/system/iptables-nat.txt
  iptables-save > "${COLLECT_DIR}"/system/iptables-save.out

  ok
}

get_common_logs()
{
  try "collect common operating system logs"

  for entry in syslog messages aws-routed-eni containers pods cloud-init.log cloud-init-output.log audit; do
    [[ -e "/var/log/${entry}" ]] && cp -fR /var/log/${entry} "${COLLECT_DIR}"/var_log/
  done

  ok
}

get_kernel_logs()
{
  try "collect kernel logs"

  if [[ -e "/var/log/dmesg" ]]; then
      cp -f /var/log/dmesg "${COLLECT_DIR}/kernel/dmesg.boot"
  fi
  dmesg > "${COLLECT_DIR}/kernel/dmesg.current"
}

get_docker_logs()
{
  try "collect Docker daemon logs"

  case "${INIT_TYPE}" in
    systemd)
      journalctl -u docker --since "${DAYS_7}" > "${COLLECT_DIR}"/docker/docker.log
      ;;
    other)
      for entry in docker upstart/docker; do
        [[ -e "/var/log/${entry}" ]] && cp --force --recursive /var/log/${entry} "${COLLECT_DIR}"/docker/
      done
      ;;
    *)
      warning "The current operating system is not supported."
      ;;
  esac

  ok
}

get_eks_logs_and_configfiles()
{
  try "collect Amazon EKS container agent logs"

  case "${INIT_TYPE}" in
    systemd)
      /bin/journalctl -u kubelet --since "${DAYS_7}" > "${COLLECT_DIR}"/eks/kubelet
      /bin/journalctl -u kubeproxy --since "${DAYS_7}" > "${COLLECT_DIR}"/eks/kubeproxy

      for entry in kubelet kube-proxy; do
        [[ -e "/etc/systemd/system/${entry}.service" ]] && cp -fR "/etc/systemd/system/${entry}.service" "${COLLECT_DIR}"/eks/
      done

      timeout 75 kubectl config view --output yaml > "${COLLECT_DIR}"/eks/kubeconfig
      ;;
    *)
      warning "The current operating system is not supported."
      ;;
  esac

  ok
}

get_pkgtype()
{
  try "detect package manager"

  if [[ "$(command -v rpm )" ]]; then
    PACKAGE_TYPE=rpm
  elif [[ "$(command -v deb )" ]]; then
    PACKAGE_TYPE=deb
  else
    PACKAGE_TYPE='unknown'
  fi

  ok
}

get_pkglist()
{
  try "detect installed packages"

  case "${PACKAGE_TYPE}" in
    rpm)
      rpm -qa > "${COLLECT_DIR}"/system/pkglist.txt 2>&1
      ;;
    deb)
      dpkg --list > "${COLLECT_DIR}"/system/pkglist.txt 2>&1
      ;;
    *)
      warning "Unknown package type."
      ;;
  esac

  ok
}

get_system_services()
{
  try "detect active system services list"

  case "${INIT_TYPE}" in
    systemd)
      systemctl list-units > "${COLLECT_DIR}"/system/services.txt 2>&1
      ;;
    other)
      /sbin/initctl list | awk '{ print $1 }' | xargs -n1 initctl show-config > "${COLLECT_DIR}"/system/services.txt 2>&1
      printf "\n\n\n\n" >> "${COLLECT_DIR}"/services.txt 2>&1
      /usr/bin/service --status-all >> "${COLLECT_DIR}"/services.txt 2>&1
      ;;
    *)
      warning "Unable to determine active services."
      ;;
  esac

  timeout 75 top -b -n 1 > "${COLLECT_DIR}"/system/top.txt 2>&1
  timeout 75 ps fauxwww > "${COLLECT_DIR}"/system/ps.txt 2>&1
  timeout 75 netstat -plant > "${COLLECT_DIR}"/system/netstat.txt 2>&1

  ok
}

get_docker_info()
{
  try "gather Docker daemon information"

  if [[ "$(pgrep dockerd)" -ne 0 ]]; then
    timeout 75 docker info > "${COLLECT_DIR}"/docker/docker-info.txt 2>&1 || echo "Timed out, ignoring \"docker info output \" "
    timeout 75 docker ps --all --no-trunc > "${COLLECT_DIR}"/docker/docker-ps.txt 2>&1 || echo "Timed out, ignoring \"docker ps --all --no-truc output \" "
    timeout 75 docker images > "${COLLECT_DIR}"/docker/docker-images.txt 2>&1 || echo "Timed out, ignoring \"docker images output \" "
    timeout 75 docker version > "${COLLECT_DIR}"/docker/docker-version.txt 2>&1 || echo "Timed out, ignoring \"docker version output \" "

    ok

  else
    die "The Docker daemon is not running."
  fi
}

get_containers_info()
{
  try "inspect running Docker containers and gather container data"

    for i in $(docker ps -q); do
      timeout 75 docker inspect "${i}" > "${COLLECT_DIR}"/docker/container-"${i}".txt 2>&1
    done

    ok
}

enable_docker_debug()
{
  try "enable debug mode for the Docker daemon"

  case "${PACKAGE_TYPE}" in
    rpm)

      if [[ -e /etc/sysconfig/docker ]] && grep -q "^\s*OPTIONS=\"-D" /etc/sysconfig/docker
      then
        info "Debug mode is already enabled."
      else

        if [[ -e /etc/sysconfig/docker ]]; then
          echo "OPTIONS=\"-D \$OPTIONS\"" >> /etc/sysconfig/docker

          try "restart Docker daemon to enable debug mode"
          /sbin/service docker restart
        fi

        ok

      fi
      ;;
    *)
      warning "The current operating system is not supported."
      ;;
  esac
}

parse_options "$@"

if [[ -z "${mode}" ]]; then
 mode="collect"
fi

case "${mode}" in
  collect)
    collect
    pack
    cleanup
    ;;
  enable_debug)
    get_pkgtype
    enable_debug
    ;;
  *)
    help && exit 1
    ;;
esac
