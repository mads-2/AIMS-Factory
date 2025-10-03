#!/usr/bin/env bash
set -euo pipefail

BASE="/work/users/m/a/mads2/CLARE/cis_AIMD_50/AIMS"
RECENT_MIN=5
TAIL_N=250
ERR_RE="${ERR_RE:-DIE called at|Job terminated}"

ERROR_BASE="error_paths_base.txt"
ERROR_RESTART="error_paths_restart.txt"
LOG_FILE="info_spawn_check_AIMD.txt"

: > "$ERROR_BASE"
: > "$ERROR_RESTART"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1   # log to file and terminal

usage() {
  cat <<EOF
Usage: $0 [-b BASE] [-m RECENT_MIN] [--tail N]
Scan AIMS/<run>/AIMD/<spawn>/tc.out and also AIMS/<run>/AIMD/<spawn>/r*/tc.out
Report: done | running | ERROR | not started yet

Writes failing base tc.out paths to:   $ERROR_BASE
Writes failing restart tc.out paths to: $ERROR_RESTART
Writes all stdout/stderr to: $LOG_FILE
EOF
}

# --- arg parse ---
while (( "$#" )); do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -b) BASE="${2:?}"; shift 2 ;;
    -m) RECENT_MIN="${2:?}"; shift 2 ;;
    --tail) TAIL_N="${2:?}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

# --- helpers ---
success_in_tc_out() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local tailtxt
  tailtxt="$(tail -n "$TAIL_N" -- "$f" || true)"
  grep -qE '^\s*\|\s*=MD=\s+Time per MD step:' <<<"$tailtxt" || return 1
  grep -qE '^\s*\|\s+Total processing time:'   <<<"$tailtxt" || return 1
  grep -qE '^\s*\|\s+Job finished:'            <<<"$tailtxt" || return 1
  return 0
}

error_in_tc_out() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local tailtxt
  tailtxt="$(tail -n "$TAIL_N" -- "$f" || true)"
  if grep -qiE "$ERR_RE" <<<"$tailtxt"; then
    return 0
  fi
  return 1
}

recent_activity() {
  local d="$1"
  [[ -d "$d" ]] || return 1
  if find "$d" -type f -mmin "-$RECENT_MIN" -print -quit >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

print_restart_info() {
  local d="$1"
  echo "    [FILES in $d]"

  # required files
  local required=(coords.xyz vels.xyz tc.in submit.sh)
  for f in "${required[@]}"; do
    if [[ -f "$d/$f" ]]; then
      echo "      - $f"
    else
      echo "      ⚠ MISSING: $f"
    fi
  done

  # list extras
  local extras=()
  while IFS= read -r f; do
    fname="$(basename "$f")"
    case " ${required[*]} " in
      *" $fname "*) continue ;;
    esac
    extras+=( "$fname" )
  done < <(find "$d" -mindepth 1 -maxdepth 1 | sort)

  if [[ ${#extras[@]} -gt 0 ]]; then
    for f in "${extras[@]}"; do
      echo "      - $f (extra)"
    done
  fi
}

# --- main scan ---
if [[ ! -d "$BASE" ]]; then
  echo "[ERROR] Base not found: $BASE" >&2
  exit 2
fi

shopt -s nullglob

runs=( "$BASE"/[0-9][0-9][0-9][0-9] )
if [[ ${#runs[@]} -eq 0 ]]; then
  echo "[INFO] No run directories under: $BASE"
  exit 0
fi

for run_dir in "${runs[@]}"; do
  run_id="$(basename "$run_dir")"
  aimd_dir="$run_dir/AIMD"
  [[ -d "$aimd_dir" ]] || { echo "${run_id}: not started yet (no AIMD/)"; continue; }

  for spawn_dir in "$aimd_dir"/*; do
    [[ -d "$spawn_dir" ]] || continue
    [[ "$(basename "$spawn_dir")" =~ ^[0-9]+$ ]] || continue
    spawn_id="$(basename "$spawn_dir")"

    # --- check base tc.out if present ---
    if [[ -e "$spawn_dir/tc.out" ]]; then
      tc="$spawn_dir/tc.out"
      label="$run_id: spawn $spawn_id"
      err_file="$ERROR_BASE"

      if success_in_tc_out "$tc"; then
        echo "$label: done"
      elif error_in_tc_out "$tc"; then
        echo "$label: ERROR ($tc)"
        echo "$tc" >> "$err_file"
      elif recent_activity "$spawn_dir"; then
        echo "$label: running"
      else
        echo "$label: ERROR (no termination flag and stale) ($tc)"
        echo "$tc" >> "$err_file"
      fi
    fi

    # --- always check all restart dirs independently ---
    for rdir in "$spawn_dir"/r[0-9]*; do
      [[ -d "$rdir" ]] || continue
      tc="$rdir/tc.out"

      label="$run_id: spawn $spawn_id/$(basename "$rdir")"
      err_file="$ERROR_RESTART"

      if [[ -e "$tc" ]]; then
        if success_in_tc_out "$tc"; then
          echo "$label: done"
        elif error_in_tc_out "$tc"; then
          echo "$label: ERROR ($tc)"
          echo "$tc" >> "$err_file"
        elif recent_activity "$rdir"; then
          echo "$label: running"
        else
          echo "$label: ERROR (no termination flag and stale) ($tc)"
          echo "$tc" >> "$err_file"
        fi
      else
        echo "$label: no tc.out"
      fi

      # print restart dir contents with warnings
      print_restart_info "$rdir"
    done
  done
done

echo "[INFO] Finished. Log saved to $LOG_FILE"

