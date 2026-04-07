# Incompressible channelPeriodic flow Simulation with OpenFOAM

![OpenFOAM Version](https://img.shields.io/badge/OpenFOAM-v2512-blue?logo=openfoam)
![License](https://img.shields.io/badge/License-MIT-green)

This project simulates a periodic channel flow featuring a NACA 0012 airfoil. It is designed for studying complex flow behavior around an airfoil in a constrained, periodic domain using **OpenFOAM (ESI-OpenCFD v2512)**.

---

## 🔬 Project Overview

- **Domain Dimensions:** $6 \times 2 \times 4$ meters.
- **Airfoil Geometry:** NACA 0012 (2m chord), centered at $(x=3, y=1, z=2)$.
- **Mesh Details:**
  - Background mesh: `blockMesh`.
  - Airfoil refinement: `snappyHexMesh`.
  - Cell Count: Approximately **1.47M cells**.
- **Physics & Solver:**
  - Solver: `pimpleFoam` (Incompressible, transient).
  - Turbulence Model: `laminar` (currently).
  - Kinematic Viscosity ($\nu$): $1 \times 10^{-4} \text{ m}^2/\text{s}$.
  - Driving Force: Bulk velocity maintained via `meanVelocityForce` in `constant/fvConstraints`.

## 🛠️ Boundary Conditions

| Patch | Type | Description |
| :--- | :--- | :--- |
| **X-Faces** | `cyclic` | Periodic flow in the stream-wise direction. |
| **Z-Faces** | `cyclic` | Periodic flow in the span-wise direction. |
| **Y-Faces** | `wall` | No-slip walls at $y=0$ and $y=2$. |
| **NACA 0012** | `wall` | No-slip airfoil surface. |

---

## 🚀 Getting Started

### 1. Prerequisites
- **OpenFOAM v2512** (or compatible ESI version).
- **Python 3** (for initial noise generation).

### 2. Mesh Generation
First, generate the background mesh and then carve out the airfoil using `snappyHexMesh`:
```bash
blockMesh
snappyHexMesh -overwrite
```

### 3. Initial Velocity Field (Perturbation)
To simulate transition or trigger turbulent-like structures, a Python utility is provided to add random noise to the velocity field.
```bash
# Generate cell centers (required by makeNoiseU.py)
postProcess -func writeCellCentres -time 0

# Apply velocity noise
python3 makeNoiseU.py
```

### 4. Running the Simulation
Use the provided `Parallel.sh` script to handle decomposition, parallel execution, and reconstruction.
```bash
./Parallel.sh
# Follow the prompt to enter the desired number of MPI processes.
```

---

## 📁 Key File Structure

- `system/snappyHexMeshDict`: Controls refinement and mesh generation around the airfoil.
- `constant/triSurface/NACA0012.obj`: The airfoil geometry surface.
- `constant/fvConstraints`: Defines the driving force (`meanVelocityForce`).
- `makeNoiseU.py`: Utility script to perturb the `0/U` internal field.
- `Parallel.sh`: Automation wrapper for the full execution workflow.
- `controlDict`: Configured for 200s runtime with binary output and compression (`on`) to manage storage efficiency.

---

## 📈 Results & Visualization
The simulation output is stored in time directories. Use `ParaView` (via `touch Incomp.foam && paraview Incomp.foam`) to visualize the pressure fields, velocity vectors, and wake structures.

---

## ⚖️ License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
