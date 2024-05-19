#!/usr/bin/python3

import sys
import os

def main():
  sys.stderr.write("Docker User: ")
  dockerUser = input()

  sys.stderr.write("Docker Password: ")
  dockerPwd = input()

  os.chmod('./run_kerberos.sh', 0o700)

  os.system("./run_kerberos.sh -u "+dockerUser+" -p "+dockerPwd)


if __name__ == '__main__':
  main()