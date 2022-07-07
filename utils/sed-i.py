#!/usr/bin/python3
import argparse
import os
import subprocess

# create parser
parser = argparse.ArgumentParser()

# Adding argument
parser.add_argument("-r", "--Root", help="Root Directory")
parser.add_argument("-s", "--Source", help="Word to be replaced.")
parser.add_argument("-t", "--Target", help="Word to replace.")

# parse the arguments
args = parser.parse_args()

parent = args.Root
pattern = args.Source
replaceWord = args.Target

# List to store all
# directories
L = []
if args.Root is None:
    parent = input("Please provide directory: ")
if args.Source is None:
    pattern = input("Pattern to search: ")
if args.Target is None:
    replaceWord = input("Replace word: ")

# Traverse through root directory
for root, dirs, files in os.walk(parent):

    # Adding the empty directory to
    # list
    L.append((root, dirs, files))
    for rfile in files:
        subprocess.call(["sed -i -e 's/" + pattern + "/" + replaceWord + "/g' " + root + "/" + rfile], shell=True)

print("sed command execution completed.")
