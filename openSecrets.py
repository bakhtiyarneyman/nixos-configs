#!/run/current-system/sw/bin/python3

import os

def sync():
  exitCode = os.system("onedrive --synchronize")
  return exitCode

if (sync() == 0):
  os.system("mkdir -p secrets")
  os.system("cryfs --foreground /home/bakhtiyar/OneDrive/mezar secrets")
  exit(sync())
else:
  exit(1)
