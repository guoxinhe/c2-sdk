#!/bin/sh -eu
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.

DIR="$(dirname $0)"
cd "$DIR"

if [ -t 1 -o -t 2 ]; then
    CONFIG_TTY=y
    echo "Working folder: $DIR"
fi

declare -a on_exit_items

function on_exit()
{
    for i in "${on_exit_items[@]}"
    do
        echo "on_exit: $i"
        eval $i
    done
}

function add_on_exit()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        echo "Setting trap"
        trap on_exit EXIT
    fi
}

touch $$-1.tmp
add_on_exit rm -f $$-1.tmp

touch $$-2.tmp
add_on_exit rm -f $$-2.tmp

ls -la *.tmp
