#!/usr/bin/env bash
BASE="/work/users/m/a/mads2/CLARE/cis_AIMD_50/AIMS"

for run_dir in "$BASE"/*; do
  run=$(basename "$run_dir")
  [[ "$run" =~ ^[0-9]{4}$ ]] || continue

  aimd="$run_dir/AIMD"
  [[ -d "$aimd" ]] || { echo "$run : 0/0 spawns finished"; continue; }

  total=0
  finished=0

  for spawn_dir in "$aimd"/*; do
    [[ -d "$spawn_dir" ]] || continue
    spawn=$(basename "$spawn_dir")
    [[ "$spawn" =~ ^[0-9]+$ ]] || continue

    ((total++))
    tc="$spawn_dir/tc.out"
    if [[ -f "$tc" ]]; then
      if tail -n 200 "$tc" | grep -q "| Job finished:" &&
         tail -n 200 "$tc" | grep -q "| Total processing time:"; then
        ((finished++))
      fi
    fi
  done

  echo "$run : $finished/$total spawns finished"
done

