#!/usr/bin/env python3

# call with path to temp dir

import os
import sys
import shutil


zip_dir = sys.path[0]

try:
    if not zip_dir : 
        raise ValueError('zip_dir')
except ValueError: 
    print(" Cannot get zip directory, you're either runninng this script interactively, or somethings terribly wrong with your PC !!!")
    sys.exit(-1) 

try:
    tmp_dir = sys.argv[1];
except IndexError: 
    print(" Not supplied temporary directory.")
    sys.exit(-1)

updater_internal_path = "META-INF/com/google/android"

updater_files = os.path.join(zip_dir, "files")

shutil.copytree(updater_files, tmp_dir );
shutil.copytree(os.path.join(zip_dir, "updater"),
os.path.join( tmp_dir , updater_internal_path))
shutil.copytree(os.path.join(zip_dir, "updater.revert"),
os.path.join(tmp_dir ,'ziprevert', updater_internal_path))
