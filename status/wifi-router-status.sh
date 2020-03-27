#!/usr/bin/env bash
# Define functions to check device status and write this to file. Intended to
# be called periodically by a systemd process.

##############################################################################
# Function to check an internet host (default 8.8.8.8) can be pinged. Returns
# 0 if ping is OK.
#
# Arguments:
#  [1] : optional alternate ping address
#
# Disable shellcheck that complains no parameters passed (they are optional):
# shellcheck disable=SC2120
function check_internet_access() {
  local ping_host='8.8.8.8'

  if [[ $# -gt 0 ]]; then
    ping_host="$1"
  fi

  ping -c 1 -w 1 "${ping_host}" > /dev/null
}

##############################################################################
# Return 0 if interface link is up; defaults to interface eth0.
#
# Arguments:
#  [1] : optional interface name
function eth0_link_detected() {
  local iface='eth0'

  if [[ $# -gt 0 ]]; then
    iface="$1"
  fi

  ethtool "${iface}" 2> /dev/null | grep -i 'Link detected: yes' > /dev/null
}

##############################################################################
# Output a JSON representation of the device's status to stdout so it can be
# easily parsed or redirected to a file.
function status_json() {
  printf \
      '{\n    "ssid": "%s", "lan": "%s", "internet": "%s",\n    "ip": %s}\n' \
      "$(iwgetid -r)" \
      "$(eth0_link_detected && printf 'UP' || printf 'DOWN')" \
      "$(check_internet_access && printf 'UP' || printf 'DOWN')" \
      "$(ip -json -pretty addr show)"
}

##############################################################################
# Persist current device status JSON to the specified file; use a temporary
# interim file to avoid potential race conditions with process(es) that may be
# reading the file. The file will be overwritten, not appended to.
#
# Arguments:
#  1 : name of file to write to
function update_status_file() {
  if [[ $# -gt 0 ]]; then
    # write to tmp file first to avoid race condition with any reading process
    status_json > "$1.tmp"
    mv "$1.tmp" "$1"
  fi
}

##############################################################################
# Entry point
#
# Arguments:
#  1 : name of file to write to
main() {
  if [[ $# -gt 0 ]]; then
    update_status_file "$1"
  else
    printf 'USAGE: ./wifi-router-status.sh output_filename\n'
  fi
}

# Pass script parameters to main function
main "$@"
