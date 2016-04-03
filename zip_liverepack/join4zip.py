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


def copytree(src, dst, symlinks = False, ignore = None):
  if not os.path.exists(dst):
    os.makedirs(dst)
    shutil.copystat(src, dst)
  lst = os.listdir(src)
  if ignore:
    excl = ignore(src, lst)
    lst = [x for x in lst if x not in excl]
  for item in lst:
    s = os.path.join(src, item)
    d = os.path.join(dst, item)
    if symlinks and os.path.islink(s):
      if os.path.lexists(d):
        os.remove(d)
      os.symlink(os.readlink(s), d)
      try:
        st = os.lstat(s)
        mode = stat.S_IMODE(st.st_mode)
        os.lchmod(d, mode)
      except:
        pass # lchmod not available
    elif os.path.isdir(s):
      copytree(s, d, symlinks, ignore)
    else:
      shutil.copy2(s, d)

updater_internal_path = "META-INF/com/google/android"

updater_hooks = os.path.join(zip_dir, "hooks")
updater_utils = os.path.join(zip_dir, "utils")
updater_liverepack = os.path.join(zip_dir, "liverepack.sh")


copytree(updater_hooks, os.path.join(tmp_dir, "hooks"));
copytree(updater_utils, os.path.join(tmp_dir, "utils"));
shutil.copy(updater_liverepack, tmp_dir );


shutil.copytree(os.path.join(zip_dir, "updater"),
os.path.join( tmp_dir , updater_internal_path))
