#!/bin/sh
printf '\033c\033]0;%s\a' Cycling through Finland - Pedal Project
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Cycling.arm64" "$@"
