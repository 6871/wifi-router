#!/usr/bin/env bash
# Configure service to show system status on a Unicorn HAT HD LED display.

# Load addional functions
. ./lib/functions.sh

##############################################################################
# Install matrix-display for LED display scrolling.
function install_matrix_display() {
  local repository='matrix-display'

  # Clone matrix-display project, unless folder already exists...
  if [[ -d "${repository}" ]]; then
    heading "WARNING: skipping git clone as \"${repository}\" dir exists" 3
  else
    if ! git clone "https://github.com/6871/${repository}"; then
      return 1
    fi
  fi

  # Ensure required software installed
  if ! sudo apt install --yes python3; then
    return 2
  fi

  if ! sudo apt install --yes python3-pip; then
    return 3
  fi

  if ! pip3 install setuptools; then
    return 4
  fi

  # Build the matrix_display package (.whl file)
  if ! pushd "${repository}"; then
    return 5
  fi

  if ! python3 setup.py bdist_wheel; then
    return 6
  fi

  # Install package
  if ! pip3 install dist/matrix_display-1.0.0-py3-none-any.whl; then
    return 7
  fi

  if ! popd; then
    return 8
  fi
}

##############################################################################
# Install software for UNicorn HAT HD LED display
function install_unicorn_hat_hd_software() {
  if ! apt install --yes python3-numpy; then
    return 1
  fi

  if ! pip3 install unicornhathd; then
    return 2
  fi
}

##############################################################################
# Install status monitor files and configure service.
function install_led_display_service() {
  if ! cp ./led_display/python/*.py /home/ubuntu/; then
    return 1
  fi

  if ! cp \
    ./led_display/services/wifi-router-display.service \
    /etc/systemd/system/
  then
    return 2
  fi

  if ! systemctl enable wifi-router-display.service; then
    return 3
  fi

  if ! systemctl start wifi-router-display.service; then
    return 4
  fi

  if ! systemctl status wifi-router-display.service; then
    return 5
  fi
}

##############################################################################
# Main function to coordinate install steps.
function main() {
  if [[ $(id -u) -eq 0 ]]; then
    heading 'install_matrix_display' 6
    if ! install_matrix_display; then
      heading 'ERROR: install_matrix_display failed' 1 >&2
      return 65
    fi

    heading 'install_unicorn_hat_hd_software' 6
    if ! install_unicorn_hat_hd_software; then
      heading 'ERROR: install_unicorn_hat_hd_software failed' 1 >&2
      return 66
    fi

    heading 'install_led_display_service' 6
    if ! install_led_display_service; then
      heading 'ERROR: install_led_display_service failed' 1 >&2
      return 67
    fi
  else
    heading 'ERROR: script must be run with sudo' >&2
    return 64
  fi
}

# Run the install
main "$@"
