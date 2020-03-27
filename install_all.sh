#!/usr/bin/env bash
# Install of all components; status service, LED display and network setup.

# Load addional functions
. ./lib/functions.sh

##############################################################################
# Main function to coordinate install steps.
function main() {
  if [[ $(id -u) -eq 0 ]]; then
    heading './install_status_service.sh' 3
    if ! ./install_status_service.sh; then
      heading 'ERROR: ./install_status_service.sh failed' 1 >&2
      return 65
    fi

    heading './install_led_display_service.sh' 3
    if ! ./install_led_display_service.sh; then
      heading 'ERROR: ./install_led_display_service.sh failed' 1 >&2
      return 66
    fi

    heading './install_network.sh' 3
    if ! ./install_network.sh "$1" "$2"; then
      heading 'ERROR: ./install_network.sh failed' 1 >&2
      return 66
    fi

    heading 'install_all.sh completed OK' 2
  else
    heading 'ERROR: script must be run with sudo' 1 >&2
    return 64
  fi
}

# Run the install
main "$@"
