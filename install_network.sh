#!/usr/bin/env bash
# Configure an Ubuntu host with an ethernet port and Wi-Fi support (e.g. a
# Raspberry Pi) as a NAT router to connect any device with an ethernet port
# to a WiFi network.
#
#        Ethernet                            Wi-Fi
#           .                                  .
#  Client   .     Ethernet to Wi-Fi Adapter    .
#  Device   .        (e.g. Raspberry Pi)       .  \|/ ... Internet
# +------+  .  +--------------------+-------+  .   |
# | eth0 |-----| eth0               | wlan0 |------+
# +------+     | 192.168.254.254/24 | DHCP  |
#    .         +--------------------+-------+
#    .    <----
#    .     DHCP (by dnsmasq)
#    .      192.168.254.100
#    .      ...
#    .      192.168.254.199
#    .
#  A router WAN port, computer, IP camera, etc...
#
# Arguments:
#  [1] : optional wifi network name; mandatory if passing network password
#  [2] : optional wifi network password; network name must also be supplied

# Load addional functions
. ./lib/functions.sh

##############################################################################
# Prevent cloud-init from interfering with manual network configuration.
function disable_cloud_init() {
  # Disable cloud init
  touch "/etc/cloud/cloud-init.disabled"

  # Remove default cloud-init config
  local cloud_init_config="/etc/netplan/50-cloud-init.yaml"
  if [ -f ${cloud_init_config} ]; then
    rm -v "${cloud_init_config}"
  else
    printf 'File "%s" not found, rm skipped\n' "${cloud_init_config}"
  fi
}

##############################################################################
# Associate hostname with 127.0.0.1 in /etc/hosts so name resolution works
# if DNS service is unavailable.
function setup_hostname() {
  if grep '^127\.0\.0\.1' /etc/hosts | grep "${HOSTNAME}" >/dev/null 2>&1; then
    printf 'No changes made, hostname "%s" already assigned to 127.0.0.1\n' \
      "${HOSTNAME}"
  else
    printf 'Assigning name "%s" to 127.0.0.1 in /etc/hosts\n' "${HOSTNAME}"
    sed -i "/127\.0\.0\.1/s/$/ ${HOSTNAME}/" /etc/hosts
  fi
}

##############################################################################
# Setup wired interface eth0 with a static IP address.
function configure_eth0() {
  # Setup lan with fixed IP; this will be the gateway IP for LAN clients
  local lan_ipv4_address=192.168.254.254/24

  # Using "optional: true" prevents hang on startup if no cable connected
  tee /etc/netplan/01-lan.yaml >/dev/null <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      dhcp6: no
      addresses:
      - ${lan_ipv4_address}
      nameservers:
        addresses:
        - 8.8.8.8
        - 8.8.4.4
      optional: true
EOF
}

##############################################################################
# Setup wireless interface wlan0 to configure itself using DHCP; the network
# name and password can be supplied as parameters, if they are not supplied
# the user will be asked to enter them.
#
# Arguments:
#  [1] : optional wifi network name; mandatory if passing network password
#  [2] : optional wifi network password; network name must also be supplied
function configure_wlan0() {
  local wan_wifi_network_name="$1"
  local wan_wifi_password="$2"

  if [[ ! ${wan_wifi_network_name} ]]; then
    printf 'Enter the WiFi network name     : '
    read -r wan_wifi_network_name
  fi

  if [[ ! ${wan_wifi_password} ]]; then
    printf 'Enter the WiFi network password : '
    read -r -s wan_wifi_password
    printf '\n'
  fi

  tee /etc/netplan/02-wan.yaml >/dev/null <<EOF
network:
  version: 2
  wifis:
    wlan0:
      dhcp4: yes
      access-points:
        "${wan_wifi_network_name}":
          password: "${wan_wifi_password}"
      nameservers:
        addresses:
        - 8.8.8.8
        - 8.8.4.4
EOF
}

##############################################################################
# Returns true if port 53 is free, false if it is used.
function port_53_is_free() {
  if ss --all --numeric | awk '{printf "%s\n", $5}' | grep ':53$' \
    >/dev/null 2>&1; then
    return 1
  fi
}

##############################################################################
# Waits a set time for port 53 to become free; returns true when free, false
# if it does not become free in the configured time.
function wait_for_port_53() {
  local r=20
  local s=5
  local i

  for ((i = 0; i < r; i++)); do
    if port_53_is_free; then
      tput setaf 2 # green
      printf 'Port 53 is not being used\n'
      tput sgr 0 # clear
      return 0
    fi

    printf "Retry %s of %s in %s seconds " "$((i + 1))" "${r}" "${s}"

    for ((j = 0; j < s; j++)); do
      printf "."
      sleep 1
    done

    printf '\n'
  done

  tput setaf 1 # red
  printf 'ERROR: Timed out waiting for port 53 to be available\n' >&2
  tput sgr 0 # clear
  return 1
}

##############################################################################
# Configures the dnsmasq service for the wired eth0 interface.
function setup_dnsmasq() {
  # Disable systemd-resolved.service
  printf 'Ensure systemd-resolved.service is not running...\n'
  systemctl stop systemd-resolved.service
  systemctl disable systemd-resolved.service

  printf 'Check for systemd-resolved.service port 53...\n'
  if systemctl is-active systemd-resolved.service; then
    wait_for_port_53
  else
    printf 'Confirmed systemd-resolved.service is not active\n'
  fi

  printf 'Installing (already downloaded) dnsmasq...\n'
  if ! apt-get install -y dnsmasq; then
    return 1
  fi

  printf 'Updating /etc/dnsmasq.conf...\n'
  file_append "/etc/dnsmasq.conf" "interface=eth0"
  file_append "/etc/dnsmasq.conf" "dhcp-range=192.168.254.100,192.168.254.199"
  file_append "/etc/dnsmasq.conf" "no-dhcp-interface=wlan0"
  file_append "/etc/dnsmasq.conf" "server=8.8.8.8"

  # Use "no-resolve" to avoid "dnsmasq[1166]: directory /etc/resolv.conf for
  # resolv-file is missing, cannot poll":
  file_append "/etc/dnsmasq.conf" "no-resolv"

  printf 'Restarting dnsmasq.service...\n'
  systemctl restart dnsmasq.service
  systemctl status --no-pager --full dnsmasq.service
}

##############################################################################
# Configures IP routing so eth0 LAN traffic can reach the WAN (e.g. internet).
function configure_ip_routing() {
  printf 'Ensure IPV4 forwarding currently enabled...\n'
  if sysctl -n net.ipv4.ip_forward | grep "1"; then
    printf 'No changes made, net.ipv4.ip_forward=1\n'
  else
    printf 'Setting net.ipv4.ip_forward=1\n'
    sysctl -w net.ipv4.ip_forward=1
  fi

  printf 'Permanently enable IPV4 forwarding...\n'
  file_append "/etc/sysctl.conf" "net.ipv4.ip_forward=1"

  printf 'Enable NAT masquarading...\n'
  if iptables -t nat --list | grep '^MASQUERADE'; then
    printf 'No changes made, iptables NAT masquerade rule present\n'
  else
    printf 'Adding iptables NAT masquerade rule for wlan0\n'
    iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
  fi

  printf 'Persist current iptables rule(s), install iptables-persistent...\n'

  printf \
    'iptables-persistent iptables-persistent/autosave_v4 boolean true\n' |
    debconf-set-selections

  printf \
    'iptables-persistent iptables-persistent/autosave_v6 boolean true\n' |
    debconf-set-selections

  # If the rules saved by the following apt-get install need to be updated
  # try: dpkg-reconfigure --frontend=noninteractive iptables-persistent

  # 180 * 10 seconds = 30 minutes
  if ! run_with_retries 180 10 apt-get install -y iptables-persistent; then
    return 1
  fi
}

##############################################################################
# Print configuration details.
function print_config() {
  heading 'iptables --table nat --list --verbose' 5
  tput setaf 4 # blue
  stdbuf --output=0 iptables --table nat --list --verbose
  tput sgr 0 # clear

  heading 'ip link' 5
  tput setaf 4 # blue
  stdbuf --output=0 ip link
  tput sgr 0 # clear

  heading 'ip route' 5
  tput setaf 4 # blue
  stdbuf --output=0 ip route
  tput sgr 0 # clear

  heading 'ip addr' 5
  tput setaf 4 # blue
  stdbuf --output=0 ip addr
  tput sgr 0 # clear
}

##############################################################################
# Apply netplan configuration.
function netplan_apply() {
  printf 'netplan settings for eth0 are:\n'
  printf -- '--- BEGIN: /etc/netplan/01-lan.yaml ---\n'
  tput setaf 4 # blue
  cat "/etc/netplan/01-lan.yaml"
  tput sgr 0 # clear
  printf -- '--- END: /etc/netplan/01-lan.yaml -----\n'
  tput setaf 3 # yellow
  printf 'SSH connections may drop now\n'
  printf 'Note above config if using static IP with wired eth0 link\n'
  printf 'To kill hanging SSH session try key sequence: [enter] [~] [.]\n'
  tput sgr 0 # clear

  netplan apply
}

##############################################################################
# Enable firewall configuration, allow ssh.
function configure_firewall() {
  ufw status
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh  # permit SSH from LAN or WAN
  ufw allow in on eth0  # permit LAN DHCP
  ufw route allow in on eth0 out on wlan0  # permit LAN internet access
  ufw --force enable  # --force avoids drop warning prompt if using ssh
  ufw status
  ufw status | grep -qw active  # function returns 1 if ufw not active
}

##############################################################################
# Disable SSH password login
function disable_ssh_password_login() {
  local sshd_config='/etc/ssh/sshd_config'
  if grep -q '^PasswordAuthentication[[:blank:]]*no' "${sshd_config}"
  then
    printf 'No changes made, \"%s\" is already set to no in \"%s\"\n' \
      'PasswordAuthentication' "${sshd_config}"
  else
    printf 'Updating \"%s\"...\n' "${sshd_config}"
    sed -i '/^PasswordAuthentication/s/yes/no/' "${sshd_config}"
    printf 'Restarting SSH...\n'
    systemctl restart ssh
  fi
}

##############################################################################
# Main function to coordinate install steps.
#
# Arguments:
#  [1] : optional wifi network name
#  [2] : optional wifi network password; network name must also be supplied
function main() {
  if [[ $(id -u) -eq 0 ]]; then
    heading 'Configure and enable firewall' 6
    if ! configure_firewall; then
      heading 'ERROR: configure_firewall failed' 1 >&2
      return 65
    fi

    heading 'Disabling SSH password login' 6
    if ! disable_ssh_password_login; then
      heading 'ERROR: disable_ssh_password_login failed' 1 >&2
      return 66
    fi

    # There are many ways to try and avoid package locking issues, the easiest
    # is to just wait a few minutes for the background apt process(es) to
    # stabilise:
    heading 'Downloading dnsmasq; retries in case of background apt locks' 6
    # 180 * 10 seconds = 30 minutes
    if ! run_with_retries 180 10 apt-get install --download-only --yes dnsmasq
    then
      heading 'ERROR: download_dnsmasq failed' 1 >&2
      return 67
    fi

    heading 'Disabling cloud init so manual network setup can be used' 6
    if ! disable_cloud_init; then
      heading 'ERROR: disable_cloud_init failed' 1 >&2
      return 68
    fi

    heading 'Assigning hostname to 127.0.0.1 (avoids sudo hang if no DNS)' 6
    if ! setup_hostname; then
      heading 'ERROR: setup_hostname failed' 1 >&2
      return 69
    fi

    heading 'Assigning static IP address tp eth0' 6
    if ! configure_eth0; then
      heading 'ERROR: configure_eth0 failed' 1 >&2
      return 70
    fi

    heading 'Connecting wlan0 to WiFi network' 6
    if ! configure_wlan0 "$@"; then
      heading 'ERROR: configure_wlan0 failed' 1 >&2
      return 71
    fi

    heading 'Verifying netplan settings' 6
    if ! netplan generate; then
      heading 'ERROR: netplan generate failed' 1 >&2
      return 72
    fi

    heading 'Applying netplan settings' 6
    if ! netplan_apply; then
      heading 'ERROR: netplan_apply failed' 1 >&2
      return 73
    fi

    heading 'Installing dnsmasq for DNS and eth0 DHCP' 6
    if ! setup_dnsmasq; then
      heading 'ERROR: setup_dnsmasq failed' 1 >&2
      return 74
    fi

    heading 'Configuring network IP routing' 6
    if ! configure_ip_routing; then
      heading 'ERROR: configure_ip_routing failed' 1 >&2
      return 75
    fi

    heading 'Device settings' 6
    print_config
    heading 'install_network.sh completed OK' 2
  else
    heading 'ERROR: script must be run with sudo' 1 >&2
    return 64
  fi
}

# Run the install
main "$@"
