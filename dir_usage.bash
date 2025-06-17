#!/bin/bash

# ------------------------------
# Script: dir_usage.sh
# Description:
#   Calculates the total disk usage of directories at a specified depth
#   from a given base directory, avoiding double-counting of hard-linked files.
#   Note this calculates actual size used including size used by directory 
#   enteries (same as du) 
# Usage:
#   ./dir_usage.sh /path/to/dir --depth=N
# ------------------------------

# Default base directory (if not specified)
BASE_DIR="."

# Default maximum depth for subdirectory traversal (if not specified)
MAX_DEPTH=1

# --- Parse input arguments ---
# Loop through all command-line arguments passed to the script
for arg in "$@"; do
    # If argument matches --depth=N (where N is a number), extract N
    if [[ "$arg" =~ --depth=([0-9]+) ]]; then
        MAX_DEPTH="${BASH_REMATCH[1]}"
    
    # If argument is a valid directory, use it as the base directory
    elif [[ -d "$arg" ]]; then
        BASE_DIR="$arg"
    fi
done

# Display summary of what the script is doing
echo "Usage for $BASE_DIR, depth $MAX_DEPTH"

# --- Setup associative array to track seen inodes ---
# Prevents counting the same file multiple times (e.g. hard links)
declare -A seen_inodes

# --- Function: Convert bytes to human-readable format ---
function human_readable() {
    num=$1
    # Use `numfmt` to convert byte count to KB, MB, GB, etc.
    # Example: 2048 -> 2.0KiB
    numfmt --to=iec --suffix=B "$num"
}

# --- Main Logic: Iterate over directories at specified depth ---
# Use `find` to locate directories at exactly MAX_DEPTH under BASE_DIR
# -mindepth and -maxdepth ensure only one specific level is targeted
#find "$BASE_DIR" -mindepth "$MAX_DEPTH" -maxdepth "$MAX_DEPTH" -type d | while read -r dir; do
find "$BASE_DIR" -mindepth "$MAX_DEPTH" -maxdepth "$MAX_DEPTH" -type d -printf '%T@ %p\n' | sort -n | cut -d' ' -f2- | while read -r dir; do

    # Initialize total size for this directory
    total_size=0

    # Recursively find all files (-type f) under this directory
    # -print0 ensures filenames with spaces/newlines are handled safely
    while IFS= read -r -d '' file; do

        # Get inode number and file size using `stat`
        # -c "%i %s" returns inode and size in bytes
	stat_out=$(stat -c "%i %b" "$file" 2>/dev/null)

        inode=$(awk '{print $1}' <<< "$stat_out")
        blocks=$(awk '{print $2}' <<< "$stat_out")

        if [[ -n "$inode" && -z "${seen_inodes[$inode]}" ]]; then
            seen_inodes[$inode]=1

            # Convert block count to bytes (512 bytes per block)
            size=$((blocks * 512))
            total_size=$((total_size + size))
        fi


    # Input to the inner loop is null-delimited list of file paths, include size taken up by directories
    done < <(find "$dir" \( -type f -o -type d \) -print0) 

    # Display total human-readable size for this directory
    echo "$dir: $(human_readable $total_size)"

done

