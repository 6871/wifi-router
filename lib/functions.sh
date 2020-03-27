#!/usr/bin/env bash
# Shared functions for wifi-router project install scripts.

##############################################################################
# Appends a line to a file unless it already exists.
#
# Arguments:
#  1 : The name of the file to be updated
#  2 : The string to be appended to the file (if it does not already exist)
function file_append() {
  if [[ $# -eq 2 ]]; then
    local file="$1"
    local line="$2"

    # Match whole line and don't use regex patterns (e.g. "." for any char)
    if grep --fixed-strings --line-regexp "${line}" "${file}"; then
      printf 'No changes, "%s" already in "%s"\n' "${line}" "${file}"
    else
      tput setaf 4 # blue
      printf 'Appending "%s" to "%s"\n' "${line}" "${file}"
      tput sgr 0 # clear
      printf '%s\n' "${line}" >>"${file}"
    fi
  else
    tput setaf 1 # red
    printf 'ERROR: file_append function needs file and line parameters\n' >&2
    tput sgr 0 # clear
    return 1
  fi
}

##############################################################################
# Try and run a command, retrying a set number of times if it fails.
#
# Arguments:
#  1  : number of times to retry on failure
#  2  : number of seconds to wait between retries
#  3+ : the command to run
function run_with_retries() {
  if [[ $# -lt 3 ]]; then
    tput setaf 1 # red
    printf 'ERROR: run_with_retries usage: %s\n' \
      'retry_count pause_seconds command [...]' >&2
    tput sgr 0 # clear
  else
    local r="$1"
    local s="$2"
    local command=("${@:3}")
    local i

    for ((i = 0; i < r; i++)); do
      printf 'run_with_retries (%s/%s): %s\n' "$((i + 1))" "$r" \
        "${command[*]}" >&2

      if ${command[*]}; then
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
    printf 'ERROR: run_with_retries gave up trying to run "%s"\n' \
      "${command[*]}" >&2
    tput sgr 0 # clear
  fi

  return 1
}

##############################################################################
# Prints a heading block.
#
# Arguments:
#  [1] : Heading text
#  [2] : Colour code; 0 Black, 1 Red, 2 Green, 3 Yellow, 4 Blue, 5 Magenta,
#        6 Cyan, 7 White.
function heading() {
  if [[ $# -gt 1 ]]; then
    tput setaf "$2"
  fi

  if [[ $# -gt 0 ]]; then
    local msg="$1"
    if [[ ${#msg} -gt 0 ]]; then
      local msg_len=$((${#msg} + 4))
      local line
      line=$(eval printf '%0.s#' "{1..${msg_len}}")
      printf '%s\n# %s #\n%s\n' "${line}" "${msg}" "${line}"
    fi
  fi

  if [[ $# -gt 1 ]]; then
    tput sgr 0 # clear
  fi
}
