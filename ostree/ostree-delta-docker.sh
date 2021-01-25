#!/bin/bash

# Copyright (c) 2021, Pelion Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -u

execdir="$(readlink -e "$(dirname "$0")")"
srcdir="$execdir"/Docker

# Load the config functions
# shellcheck disable=SC1090
source "$srcdir/config-funcs.sh"

imagename="ostree-delta-update-tools"
containername="ostree-delta-update-container.$$"
build_script=ostree-delta.py
dockerfile=Docker/Dockerfile

trap cleanup 0

cleanup() {
    # This command will return an id (eg. 43008e2a9f5a) of the running
    # container
    running_container="$(docker ps -q -f name="$containername")"
    if [ ! -z "$running_container" ]; then
        docker kill "$containername"
    fi
}

quiet_printf() {
    if [ "$quiet" -ne 1 ]; then
        # Shellcheck warns about printf's format string being variable, but
        # quiet_printf is just forwarding args to printf, so it's
        # quiet_printf's caller's responsibility to ensure that quiet_printf's
        # format string isn't variable.
        # shellcheck disable=SC2059
        printf "$@"
    fi
}

run_quietly() {
    if [ "$quiet" -ne 1 ]; then
        "$@"
    else
        "$@" > /dev/null
    fi
}


usage()
{
  cat <<EOF

usage: ostree-delta-docker.sh [OPTION] -- [build.sh arguments]

MANDATORY parameters:
  --output PATH      Specify the output folder
  --repo PATH        Specify the root of the build tree.

OPTIONAL parameters:
  --update_repo PATH        Specify the root of the build tree.
  -h, --help            Print brief usage information and exit.
  --quiet               Reduce amount of output.
  -x                    Enable shell debugging in this script.

EOF
}

flag_tty="-t"
quiet=0

# Read or write configuration files and return combined args array
config=()
config_setup config "$@"

# Set up args including values from config
# Shell check wants us to quote the printf substitution to prevent word
# splitting here, but we *want* word splitting of printf's output. The "%q" in
# printf's format string means that the word splitting will happen in the right
# places.
# shellcheck disable=SC2046
eval set -- "${config[@]}"

# Save the full command line for later - when we do a binary release we want a
# record of how this script was invoked
command_line="$(printf '%q ' "$0" "$@")"

args_list="output:"
args_list="${args_list},repo:"
args_list="${args_list},update_repo:"
args_list="${args_list},help"
args_list="${args_list},quiet"

args=$(getopt -o+ho:x -l $args_list -n "$(basename "$0")" -- "$@")
eval set -- "$args"

while [ $# -gt 0 ]; do
  if [ -n "${opt_prev:-}" ]; then
    eval "$opt_prev=\$1"
    opt_prev=
    shift 1
    continue
  elif [ -n "${opt_append:-}" ]; then
    eval "$opt_append=\"\${$opt_append:-} \$1\""
    opt_append=
    shift 1
    continue
  fi
  case $1 in
  --repo)
    opt_prev=repo
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  --update_repo)
    opt_prev=update_repo
    ;;

  -o | --output)
    opt_prev=output
    ;;

  --quiet)
    quiet=1
    ;;

  -x)
    set -x
    ;;

  --)
    shift
    break 2
    ;;
  esac
  shift 1
done

if [ -n "${repo:-}" ]; then
  repo=$(readlink -f "$repo")
  if [ ! -d "$repo" ]; then
    quiet_printf "missing repo %s.\n" "$repo"
    exit 1
  fi
else
  quiet_printf "missing repo argument.\n" 
  exit 1
fi

if [ -n "${output:-}" ]; then
  output=$(readlink -f "$output")
  if [ ! -d "$output" ]; then
    quiet_printf "missing output %s. Creating it.\n" "$output"
    mkdir -p "$output"
  fi
else
  quiet_printf "missing output argument.\n" 
  exit 1
fi

if [ -n "${update_repo:-}" ]; then
  update_repo=$(readlink -f "$update_repo")
  if [ ! -d "$update_repo" ]; then
    quiet_printf "missing repo %s.\n"
    exit 1
  fi
fi

dockerfile_path="$execdir/$dockerfile"

# Build the docker build environment
set -x
run_quietly docker build -f "$dockerfile_path" -t "$imagename" "$execdir"

set -x

# The ${:+} expansion of download upsets shellcheck, but we do not
# want that instance quoted because that would inject an empty
# argument when download is not defined.
# shellcheck disable=SC2086
docker run --rm -i $flag_tty \
       --name "$containername" \
       -e LOCAL_UID="$(id -u)" -e LOCAL_GID="$(id -g)" \
       ${repo:+-v "$repo":"$repo"} \
       ${output:+-v "$output":"$output"} \
       ${update_repo:+-v "$update_repo":"$update_repo"} \
       "$imagename" \
       ./${build_script} --repo "$repo" \
         --output "$output" \
         ${update_repo:+--update_repo "$update_repo"} \
         "$@"
