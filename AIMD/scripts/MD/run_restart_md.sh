#!/usr/bin/env bash
set -euo pipefail

BASE="/work/users/m/a/mads2/CLARE/cis_AIMD_50"

echo "[INFO] Searching for r# directories with tc.in but no tc.out under: $BASE"

# Find restart directories r1, r2, r3, ...
mapfile -t PENDING_DIRS < <(
  find "$BASE" -type d -regex ".*/r[0-9]+" | sort |
  while read -r d; do
    if [[ -f "$d/tc.in" && ! -f "$d/tc.out" ]]; then
      # Only keep dirs where coords.xyz and vels.xyz exist and are non-empty
      if [[ -s "$d/coords.xyz" && -s "$d/vels.xyz" ]]; then
        echo "$d"
      fi
    fi
  done
)

if [[ ${#PENDING_DIRS[@]} -eq 0 ]]; then
  echo "[INFO] No pending r# directories found that meet criteria."
  exit 0
fi

echo "[INFO] Found ${#PENDING_DIRS[@]} pending restart directories with valid coords/vels:"
printf '  %s\n' "${PENDING_DIRS[@]}"

# Confirm before submission
read -p "Do you want to submit jobs for ALL these directories? [y/N] " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "[INFO] Aborting."
  exit 0
fi

# Submit jobs
for d in "${PENDING_DIRS[@]}"; do
  if [[ -f "$d/submit.sh" ]]; then
    echo "[INFO] Submitting job in $d"
    (cd "$d" && sbatch submit.sh)
  else
    echo "[WARN] No submit.sh in $d — skipping."
  fi
done

echo "[INFO] Done. Submitted ${#PENDING_DIRS[@]} jobs."

