#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f system/controlDict ]]; then
  echo "Error: Run this from an OpenFOAM case directory (system/controlDict not found)."
  exit 1
fi
if [[ ! -f system/decomposeParDict ]]; then
  echo "Error: system/decomposeParDict not found."
  exit 1
fi

echo "Case directory: $(pwd)"
echo

echo "Deleting time directories (keeps 0/)..."
foamListTimes -rm

echo "Deleting postProcessing, logs, processor dirs..."
rm -rf processor* postProcessing log.* PostPr* 2>/dev/null || true
echo "Cleanup done."
echo

read -r -p "Enter number of MPI processes: " NP
if ! [[ "$NP" =~ ^[0-9]+$ ]] || [[ "$NP" -lt 1 ]]; then
  echo "Error: number of processes must be a positive integer."
  exit 1
fi
echo "Using $NP MPI processes"
echo

echo "Updating numberOfSubdomains in system/decomposeParDict"
cp -f system/decomposeParDict system/decomposeParDict.bak
sed -i -E "s/^([[:space:]]*numberOfSubdomains[[:space:]]+)[0-9]+([[:space:]]*;)/\1${NP}\2/" system/decomposeParDict
echo "decomposeParDict updated."
echo

echo "Running decomposePar..."
decomposePar -force > log.decomposePar 2>&1

echo "Running foamRun (incompressibleFluid) in parallel..."
set +e
mpirun -np "$NP" foamRun -solver incompressibleFluid -parallel 2>&1 | tee log.foamRun
foam_rc=${PIPESTATUS[0]}
set -e

if [[ $foam_rc -ne 0 ]]; then
  echo "foamRun failed with exit code $foam_rc"
  exit $foam_rc
fi

echo
echo "Finalising parallel run"
echo

# -------------------------------------------------------
# Reconstruct ONLY if at least one numeric time exists in ANY processor dir
# -------------------------------------------------------
echo "Reconstructing results (only if time directories exist)..."

# Look for any "processor*/<time>" directories where <time> is numeric (e.g. 0.005, 0.01, 0.05)
if find processor* -maxdepth 1 -type d -regextype posix-extended \
      -regex '.*/[0-9]+(\.[0-9]+)?' -print -quit 2>/dev/null | grep -q .; then
  reconstructPar > log.reconstructPar 2>&1 || {
    echo "reconstructPar returned non-zero. See log.reconstructPar (continuing anyway)."
  }
else
  echo "No written time directories found in processor* dirs. Skipping reconstructPar."
fi

echo
echo "All done."

