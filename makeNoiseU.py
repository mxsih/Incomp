#!/usr/bin/env python3
"""
makeNoiseU.py
Adds small random perturbations to the INITIAL velocity field (0/U) for a periodic channel case.

Requirements:
  - Run first: postProcess -func writeCellCentres -time 0
    (this creates 0/C)

Usage (from anywhere):
  python3 /path/to/channelPeriodic/makeNoiseU.py

What it does:
  - Reads 0/C to get number of cells
  - Builds a nonuniform internalField for 0/U with random noise in Uy and Uz (Ux=0)
  - Keeps boundaryField untouched
  - Saves backup: 0/U.bak
"""

import re
from pathlib import Path

import numpy as np


def main() -> None:
    # Always use the script location as the case root (safe if you run it from system/)
    case = Path(__file__).resolve().parent
    Ufile = case / "0" / "U"
    Cfile = case / "0" / "C"

    # ---------------- USER KNOBS ----------------
    amp = 0.1   # noise amplitude in m/s (try 0.005–0.05 depending on your bulk velocity)
    seed = 7     # random seed for reproducibility
    # --------------------------------------------

    print(f"[makeNoiseU] case = {case}")
    print(f"[makeNoiseU] Ufile = {Ufile} exists={Ufile.exists()}")
    print(f"[makeNoiseU] Cfile = {Cfile} exists={Cfile.exists()}")

    if not Ufile.exists():
        raise FileNotFoundError(f"Missing file: {Ufile}")
    if not Cfile.exists():
        raise FileNotFoundError(
            f"Missing file: {Cfile}\n"
            f"Run this first in the case root:\n"
            f"  postProcess -func writeCellCentres -time 0"
        )

    txtU = Ufile.read_text()
    txtC = Cfile.read_text()

    # Parse number of cells from 0/C internalField
    m = re.search(r"internalField\s+nonuniform\s+List<vector>\s*\n(\d+)\s*\n\(", txtC, re.M)
    if not m:
        raise RuntimeError("Could not parse 0/C as 'internalField nonuniform List<vector>' (unexpected format).")
    nCells = int(m.group(1))

    # Extract vectors from 0/C (first nCells vectors after internalField)
    block = txtC.split("internalField", 1)[1]
    vecs = re.findall(r"\(\s*([eE0-9\+\-\.]+)\s+([eE0-9\+\-\.]+)\s+([eE0-9\+\-\.]+)\s*\)", block)
    if len(vecs) < nCells:
        raise RuntimeError(f"Parsed only {len(vecs)} vectors from 0/C, expected {nCells}.")

    rng = np.random.default_rng(seed)

    # Random perturbations (zero-mean) in y and z only; keep x = 0 initially
    Uy = rng.standard_normal(nCells)
    Uz = rng.standard_normal(nCells)
    Uy -= Uy.mean()
    Uz -= Uz.mean()

    U = np.ones((nCells, 3))
    U[:, 1] = amp * Uy
    U[:, 2] = amp * Uz

    # Build OpenFOAM 'nonuniform List<vector>' internalField block
    Ulist = "\n".join(f"({u[0]:.8e} {u[1]:.8e} {u[2]:.8e})" for u in U)
    new_internal = (
        f"internalField   nonuniform List<vector>\n"
        f"{nCells}\n"
        f"(\n"
        f"{Ulist}\n"
        f");\n"
    )

    # Replace existing internalField (uniform or nonuniform) in 0/U
    # This targets either:
    #   internalField uniform (.. .. ..);
    # or
    #   internalField nonuniform List<vector> ... );
    txtU2, nsubs = re.subn(
        r"internalField\s+(?:uniform\s+\([^\)]+\)|nonuniform\s+List<vector>\s*\n\d+\s*\n\([\s\S]*?\)\s*\)\s*;)\s*;",
        new_internal.strip() + "\n",
        txtU,
        count=1,
        flags=re.M
    )

    if nsubs == 0:
        # Fall back to a simpler uniform-only replacement (covers many cases)
        txtU2, nsubs = re.subn(
            r"internalField\s+uniform\s+\([^\)]+\);\s*",
            new_internal,
            txtU,
            count=1,
            flags=re.M
        )

    if nsubs == 0:
        raise RuntimeError(
            "Could not find/replace internalField in 0/U.\n"
            "Paste your 0/U internalField lines here and I’ll match the exact format."
        )

    # Backup and write
    bak = Ufile.with_suffix(".bak")
    bak.write_text(txtU)
    Ufile.write_text(txtU2)

    print(f"✅ Updated 0/U internalField with random noise")
    print(f"   amp   = {amp} m/s")
    print(f"   seed  = {seed}")
    print(f"   cells = {nCells}")
    print(f"✅ Backup saved as: {bak}")


if __name__ == "__main__":
    main()
