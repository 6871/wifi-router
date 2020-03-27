#!/usr/bin/env bash
# Configure service to periodically update a file with status information.

# Load addional functions
. ./lib/functions.sh

##############################################################################
# Install packages to simplify getting network status (ethtool, iwgetid, ...)
function install_os_network_packages() {
  if ! apt-get install --yes iw; then
    return 1
  fi

  if ! apt-get install --yes wireless-tools; then
    return 2
  fi
}

##############################################################################
# Install status monitor files and configure service.
function install_status_service() {
  if ! cp ./status/wifi-router-status.sh /usr/local/sbin/; then
    return 1
  fi

  if ! chmod +x /usr/local/sbin/wifi-router-status.sh; then
    return 2
  fi

  if ! cp ./status/services/wifi-router-status.service /etc/systemd/system/
  then
    return 3
  fi

  if ! systemctl enable wifi-router-status.service; then
    return 4
  fi

  if ! systemctl start wifi-router-status.service; then
    return 5
  fi

  if ! systemctl status wifi-router-status.service; then
    return 6
  fi
}

##############################################################################
# Main function to coordinate install steps.
function main() {
  if [[ $(id -u) -eq 0 ]]; then
    heading 'install_os_network_packages' 6
    if ! install_os_network_packages; then
      heading 'ERROR: install_os_network_packages failed' 1 >&2
      return 65
    fi

    heading 'install_status_service' 6
    if ! install_status_service; then
      heading 'ERROR: install_status_service failed' 1 >&2
      return 66
    fi

    heading 'Install completed OK' 2
  else
    heading 'ERROR: script must be run with sudo' 1 >&2
    return 64
  fi
}

# Run the install
main "$@"
