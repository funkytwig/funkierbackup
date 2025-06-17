#!/bin/bash

# Usage: ./dir_usage.sh /path/to/dir --depth=N

BASE_DIR="."
MAX_DEPTH=1

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" =~ --depth=([0-9]+) ]]; then
        MAX_DEPTH="${BASH_REMATCH[1]}"
    elif [[ -d "$arg" ]]; then
        BASE_DIR="$arg"
    fi
done

echo "Usage for $BASE_DIR, depth $MAX_DEPTH"

# Store seen inodes
declare -A seen_inodes

# Convert to human-readable
function human_readable() {
    num=$1
    numfmt --to=iec --suffix=B "$num"
}

# Find directories at given depth
find "$BASE_DIR" -mindepth "$MAX_DEPTH" -maxdepth "$MAX_DEPTH" -type d | while read -r dir; do
    total_size=0

    # Find files inside each directory (recursively), track inodes
    while IFS= read -r -d '' file; do

        stat_out=$(stat -c "%i %s" "$file" 2>/dev/null)
        inode=$(awk '{print $1}' <<< "$stat_out")
        size=$(awk '{print $2}' <<< "$stat_out")

        if [[ -n "$inode" && -z "${seen_inodes[$inode]}" ]]; then

            seen_inodes[$inode]=1
            total_size=$((total_size + size))
        fi
    done < <(find "$dir" -type f -print0)

    echo "$dir: $(human_readable $total_size)"
done

