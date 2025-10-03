#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="info_create_restart_md.txt"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Default behavior:
#   If no arg given → process both base + restart errors.
#   If one file given → process just that one.
if [[ $# -eq 0 ]]; then
  FILES=("error_paths_base.txt" "error_paths_restart.txt")
else
  FILES=("$@")
fi

# Validate error files
ERR_PATHS=()
for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo "[INFO] Loading errors from: $f"
    while IFS= read -r line; do
      [[ -n "$line" ]] && ERR_PATHS+=("$line")
    done < <(sed 's/\r$//' "$f" | awk 'NF')
  else
    echo "[WARN] $f not found, skipping."
  fi
done

if [[ ${#ERR_PATHS[@]} -eq 0 ]]; then
  echo "[INFO] No error paths to process."
  exit 0
fi

echo "[INFO] Loaded ${#ERR_PATHS[@]} error paths."

# ----------------------------------------------------------------------
# Parse info_spawn_check_AIMD.txt for "done" restarts
# ----------------------------------------------------------------------
declare -A DONE_PATHS
if [[ -f "info_spawn_check_AIMD.txt" ]]; then
  while IFS= read -r line; do
    # Skip ERROR/running lines
    if [[ "$line" =~ ERROR ]] || [[ "$line" =~ running ]]; then
      continue
    fi
    if [[ "$line" =~ ^([0-9]{4}):[[:space:]]+spawn[[:space:]]+([0-9]+)(/r[0-9]+)?:[[:space:]]+done ]]; then
      sys="${BASH_REMATCH[1]}"
      spawn="${BASH_REMATCH[2]}"
      rpart="${BASH_REMATCH[3]}"
      key="${sys}_${spawn}${rpart}"
      DONE_PATHS["$key"]=1
    fi
  done < info_spawn_check_AIMD.txt
  echo "[INFO] Loaded ${#DONE_PATHS[@]} done entries from info_spawn_check_AIMD.txt"
else
  echo "[WARN] info_spawn_check_AIMD.txt not found, cannot enforce r3+ safety"
fi

# ----------------------------------------------------------------------
# Helper to extract last block of coords/vels
# ----------------------------------------------------------------------
extract_last_block() {
  local src="$1" dst="$2" tag="$3"
  if [[ ! -f "$src" ]]; then
    echo "  WARNING: missing $src"
    return 1
  fi
  local start total
  start="$(grep -n '^[0-9][0-9]*$' -- "$src" | tail -1 | cut -d: -f1 || true)"
  if [[ -z "${start:-}" ]]; then
    echo "  WARNING: could not find a block header in $src"
    return 1
  fi
  total="$(wc -l < "$src")"

  head -n 1 "$src" | tail -n 1 > "$dst"
  echo "$tag" >> "$dst"
  sed -n "$((start+2)),$total p" -- "$src" >> "$dst"
  return 0
}

# ----------------------------------------------------------------------
# Main loop
# ----------------------------------------------------------------------
for tcpath in "${ERR_PATHS[@]}"; do
  if [[ ! -f "$tcpath" ]]; then
    echo "[WARN] tc.out not found (skipping): $tcpath"
    continue
  fi

  AIMD_DIR="$(dirname "$tcpath")"
  # If AIMD_DIR itself is a restart dir, go up one
  if [[ "$(basename "$AIMD_DIR")" =~ ^r[0-9]+$ ]]; then
    AIMD_DIR="$(dirname "$AIMD_DIR")"
  fi

  SCR_DIR="$AIMD_DIR/scr.coords"

  echo "Processing error path: $tcpath"
  echo "  AIMD directory: $AIMD_DIR"

  last_rdir=""
  max_idx=0
  for d in "$AIMD_DIR"/r[0-9]*; do
    [[ -d "$d" ]] || continue
    idx="${d##*/r}"
    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx > max_idx )); then
      max_idx=$idx
      last_rdir="$d"
    fi
  done

  src_coords=""
  src_vels=""
  if (( max_idx > 0 )) && [[ -f "$last_rdir/coords.xyz" && -f "$last_rdir/vels.xyz" ]]; then
    src_coords="$last_rdir/coords.xyz"
    src_vels="$last_rdir/vels.xyz"
  else
    src_coords="$SCR_DIR/coors.xyz"
    src_vels="$SCR_DIR/velocities.xyz"
  fi

  next_idx=$((max_idx+1))
  next_rdir="$AIMD_DIR/r$next_idx"

  # ------------------------------------------------------------------
  # Safety rule: only allow r3+ if previous restart was "done"
  # ------------------------------------------------------------------
  if (( next_idx >= 3 )); then
    sys_base="$(basename "$(dirname "$AIMD_DIR")")"  # e.g. 0001
    spawn_id="$(basename "$AIMD_DIR")"              # e.g. 26
    prev_key="${sys_base}_${spawn_id}/r$max_idx"
    if [[ -z "${DONE_PATHS[$prev_key]:-}" ]]; then
      echo "  [SKIP] Not creating r$next_idx because $AIMD_DIR/r$max_idx is not marked done."
      continue
    fi
  fi

  mkdir -p "$next_rdir"

  echo "  → New restart dir: $next_rdir"
  echo "  → Source coords:   $src_coords"
  echo "  → Source vels:     $src_vels"

  aimd_base="$(basename "$(dirname "$AIMD_DIR")")"
  aimd_sub="$(basename "$AIMD_DIR")"
  restart_tag="$(basename "$next_rdir")"
  tag="$aimd_base     $aimd_sub     $restart_tag"

  if ! extract_last_block "$src_coords" "$next_rdir/coords.xyz" "$tag"; then
    echo "  ERROR: failed to write $next_rdir/coords.xyz"
  fi
  if ! extract_last_block "$src_vels" "$next_rdir/vels.xyz" "$tag"; then
    echo "  ERROR: failed to write $next_rdir/vels.xyz"
  fi

  for f in submit.sh tc.in; do
    if [[ -f "$AIMD_DIR/$f" ]]; then
      cp -f "$AIMD_DIR/$f" "$next_rdir/"
    else
      echo "  WARNING: missing $AIMD_DIR/$f"
    fi
  done
done

echo "[INFO] Done."

