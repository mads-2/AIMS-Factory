# Molecular Dynamics (MD)

## What is AIMD?

AIMD (Ab Initio Molecular Dynamics) allows you to continue nuclear motion after AIMS spawning events. Each spawn point can be extended into a physically meaningful MD trajectory on the lower electronic state.

This workflow turns AIMS spawns into **regular MD trajectories**, enabling you to simulate how nuclear motion evolves after a system moves from the upper state to the lower electronic state.

---

## Pre-Steps: Preparing AIMS Data

1. AIMD is only run on **finished AIMS runs**. Your AIMS setup typically looks like:
   ```
   .../<molecule>/AIMS/####
   ```

2. Make a new directory for AIMD:
   ```
   .../<molecule>/AIMD/
   ```

3. Copy your finished AIMS runs (e.g., `0000/`, `0001/`, `0002/`) into:
   ```
   .../<molecule>/AIMD/AIMS/
   ```

   ⚠️ **Important**: This copy must be recursive (all contents, not just the folders). Copying can take a long time—consider writing a copy script and submitting it to the cluster instead of running on your local machine.

4. Use the helper script (`aimd_aims_copy.sh`) to automate copying. It will:
   - Create `AIMD/`
   - Make an empty `AIMD/AIMS/` directory
   - Copy selected `####/` directories into `AIMD/AIMS/####/`

---

## Part A: AIMD_prep

1. Inside `.../<molecule>/AIMD/`, create a folder:
   ```
   AIMD_prep/
   ```

2. Inside `AIMD_prep/`, add:
   - `submit.sh` → your SLURM submission file (adjust for your cluster: partition, GPU, memory, etc)
   - `tc.in` → the TeraChem MD input file

These provide the template for all AIMD runs.

---

## Part B: Setting Up Core AIMD Scripts

Place these scripts in your `.../<molecule>/AIMD/` directory:

- **`AIMS_summary.sh`**  
  Summarizes which AIMS runs are finished and whether AIMD jobs have been set up.

- **`AIMD_gen_list.sh`**  
  Reads the summary and creates a list (`AIMD_preplist.txt`) of which initial conditions are ready to continue into AIMD.

- **`AIMD_execute.sh`**  
  Uses the preplist to:
  - Create AIMD directories under each finished AIMS run  
  - Copy `tc.in` and `submit.sh` from `AIMD_prep/`  
  - Generate `coords.xyz` and `vels.xyz` for each spawn point  
  - Submit jobs with `sbatch`

### Workflow order

Run the following in sequence:

```
./AIMS_summary.sh
./AIMD_gen_list.sh
./AIMD_execute.sh
```

---

## Part C: Accessory Scripts

These additional scripts help with monitoring and restarting AIMD runs:

- **`spawn_check_AIMD.sh`**  
  Logs the status of all AIMD runs.  
  - Output: `info_spawn_check_AIMD.txt` (user-readable summary)  
  - Output: `error_paths_base.txt` and `error_paths_restart.txt` (lists of failed runs)  

  Status categories:  
  - **done** → run finished successfully (`tc.out` has completion markers)  
  - **running** → run in progress (`tc.out` updating)  
  - **ERROR** → run failed or stalled  

- **`create_restart_md.sh`**  
  Uses the error path files to create new restart directories (`r1/`, `r2/`, …) with the required restart files.  
  - Output: `info_create_restart_md.txt`  

- **`run_restart_md.sh`**  
  Searches for restart directories containing `tc.in` but no `tc.out`.  
  Prints a list and asks for confirmation before submitting jobs with `sbatch`.

---

## Monitoring and Error Handling

1. To monitor AIMD progress:
   ```
   ./spawn_check_AIMD.sh
   ```
   This gives you a detailed status report of all spawns.

2. To handle errors:
   - Run `create_restart_md.sh` to make new restart directories.  
   - Run `run_restart_md.sh` to launch the restart jobs.

---

## Notes

- Copying AIMS directories can be slow — always prefer batch copy scripts.  
- AIMD currently supports **MD runs only**.  
- **Optimization workflows** (continuing from the end of trajectories) are planned but not yet implemented.

