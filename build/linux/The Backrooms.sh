#!/bin/sh
echo -ne '\033c\033]0;The Backrooms\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/The Backrooms.x86_64" "$@"
