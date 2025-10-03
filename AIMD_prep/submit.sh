#!/bin/bash

#SBATCH -p # add partition name
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J # add your job name
#SBATCH --mem=50G
#SBATCH -t 10:00:00
#SBATCH --qos gpu_access
#SBATCH --gres=gpu:1

#Load necessary modules

module load tc/25.03

terachem tc.in > tc.out
