#!/usr/bin/env bash
# Benchmark.sh
# Benchmarks foamRun using Parallel.sh with reliable wall-time measurement (GNU /usr/bin/time).
# - Asks stepping method: +1 or x2
# - Asks min/max MPI ranks to test
# - Caps max to available CPU threads (nproc)
#
# Requirements:
#   - Run from the OpenFOAM case directory
#   - ./Parallel.sh exists and is executable, and reads NP from stdin

set -euo pipefail

PARALLEL_SCRIPT="./Parallel.sh"
RESULTS_FILE="benchmark_results.dat"
TIMEBIN="/usr/bin/time"

# ---- checks ----
if [[ ! -x "$PARALLEL_SCRIPT" ]]; then
  echo "Error: $PARALLEL_SCRIPT not found or not executable."
  echo "Fix: chmod +x Parallel.sh"
  exit 1
fi

if [[ ! -f system/controlDict ]]; then
  echo "Error: system/controlDict not found. Run this from the OpenFOAM case directory."
  exit 1
fi

if [[ ! -x "$TIMEBIN" ]]; then
  echo "Error: $TIMEBIN not found. Install GNU time (package: time)."
  exit 1
fi

MAX_AVAIL="$(nproc)"
echo "Available CPU threads: $MAX_AVAIL"
echo

# ---- method ----
echo "Stepping method:"
echo "  1) +1 each time  (2,3,4,...)"
echo "  2) x2 each time  (2,4,8,...)"
read -r -p "Choose [1/2] (default 1): " METHOD
METHOD="${METHOD:-1}"
if [[ "$METHOD" != "1" && "$METHOD" != "2" ]]; then
  echo "Error: choose 1 or 2."
  exit 1
fi

# ---- range ----
read -r -p "MIN MPI ranks to test (>=2) (default 2): " MIN_RANKS
MIN_RANKS="${MIN_RANKS:-2}"

read -r -p "MAX MPI ranks to test (<=${MAX_AVAIL}) (default ${MAX_AVAIL}): " MAX_RANKS
MAX_RANKS="${MAX_RANKS:-$MAX_AVAIL}"

if ! [[ "$MIN_RANKS" =~ ^[0-9]+$ && "$MAX_RANKS" =~ ^[0-9]+$ ]]; then
  echo "Error: MIN/MAX must be integers."
  exit 1
fi
if [[ "$MIN_RANKS" -lt 2 ]]; then
  echo "Error: MIN must be >= 2 (OpenFOAM -parallel requires >=2)."
  exit 1
fi
if [[ "$MAX_RANKS" -gt "$MAX_AVAIL" ]]; then
  echo "Error: MAX cannot exceed available CPU threads ($MAX_AVAIL)."
  exit 1
fi
if [[ "$MIN_RANKS" -gt "$MAX_RANKS" ]]; then
  echo "Error: MIN cannot be greater than MAX."
  exit 1
fi

echo
if [[ "$METHOD" == "1" ]]; then
  echo "Benchmarking MPI ranks ${MIN_RANKS} -> ${MAX_RANKS} (step +1)"
else
  echo "Benchmarking MPI ranks ${MIN_RANKS} -> ${MAX_RANKS} (step x2)"
fi
echo

# ---- results header ----
echo "# MPI_Ranks  WallTime_seconds" > "$RESULTS_FILE"

best_np=""
best_time=""

run_one() {
  local NP="$1"
  local tmp
  tmp="$(mktemp)"

  echo "=============================="
  echo "Running with $NP MPI processes"
  echo "=============================="

  # /usr/bin/time writes to stderr; capture it in tmp.
  # Redirect Parallel.sh output away so tmp contains ONLY the time number.
  printf "%d\n" "$NP" | "$TIMEBIN" -f "%e" "$PARALLEL_SCRIPT" \
    >/dev/null 2>"$tmp" || { cat "$tmp"; rm -f "$tmp"; exit 1; }

  local t
  t="$(tr -d ' \t\r\n' < "$tmp")"
  rm -f "$tmp"

  if ! [[ "$t" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Warning: time parse failed for NP=$NP (got: '$t')"
    t="NaN"
  fi

  echo "$NP  $t" >> "$RESULTS_FILE"
  echo "Recorded: NP=$NP  Time=${t}s"
  echo

  if [[ "$t" != "NaN" ]]; then
    if [[ -z "$best_time" ]] || awk -v a="$t" -v b="$best_time" 'BEGIN{exit !(a<b)}'; then
      best_time="$t"
      best_np="$NP"
    fi
  fi
}

if [[ "$METHOD" == "1" ]]; then
  for NP in $(seq "$MIN_RANKS" "$MAX_RANKS"); do
    run_one "$NP"
  done
else
  NP="$MIN_RANKS"
  while [[ "$NP" -le "$MAX_RANKS" ]]; do
    run_one "$NP"
    NP=$((NP * 2))
  done
fi

echo "Benchmark completed."
echo "Results saved to: $RESULTS_FILE"
if [[ -n "$best_np" ]]; then
  echo "Best: NP=$best_np  Time=${best_time}s"
fi

