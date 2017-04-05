#!/usr/bin/env python

import os
import sys
import subprocess

#Very hacky. Don't judge.

# Runs 'cmd' and returns the output.
def get_shell_cmd_output(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as cmdexception:
        raise Exception("Failed to run cmd: %s\n" % cmd)

def download_to_location(filepath, download_location):
    with open(filepath) as file_obj:
        content = file_obj.readlines()
        for line in content:
            if not line.strip():
                continue
            try:
                cmd = "aws s3 cp " + line.strip() + " " + download_location
                print cmd
                get_shell_cmd_output(cmd)
            except:
                sys.stderr.write("Something went wrong\n")
                return False;
    return True;

if __name__ == "__main__":
    if (len(sys.argv) != 3):
        sys.stderr.write("Takes only two arguments - path to file with s3 buckets and s3 location to copy to\n")
        sys.exit(1)
    if(download_to_location(sys.argv[1], sys.argv[2])):
        sys.stdout.write("Upload succesful\n")
        sys.exit(0)
    sys.exit(1)
