#!/usr/bin/env python

#Very hacky. Don't judge.
import os
import sys
import subprocess

# Runs 'cmd' and returns the output.
def get_shell_cmd_output(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as cmdexception:
        raise Exception("Failed to run cmd: %s\n" % cmd)

def upload_to_s3(filename, download_location):
    print "Upload " + filename + " to " + download_location
    cmd = "aws s3 cp " + filename + " " + download_location
    get_shell_cmd_output(cmd)

def download_to_local(line, filename):
    cmd = "curl -o " + filename + " " + line.strip()
    print "Download " + line.strip() + " to local path " + filename
    get_shell_cmd_output(cmd)

def extract_zip_and_upload(filename, download_location):
    print "Creating tmp1234 directory"
    cmd = "mkdir -p tmp1234"
    get_shell_cmd_output(cmd)
    print "Extracting " + filename + " to tmp1234 dir"
    cmd = "unzip " + filename + " -d tmp1234/"
    get_shell_cmd_output(cmd)
    list_files = os.listdir("tmp1234")
    for file in list_files:
        uncompressed_file_name = "tmp1234/" + file.strip()
        if (os.path.isfile(uncompressed_file_name) and uncompressed_file_name.endswith("csv")):
            upload_to_s3(uncompressed_file_name, download_location)
    cmd = "rm -rf tmp1234"
    get_shell_cmd_output(cmd)


def process_input(filepath, download_location):
    with open(filepath) as file_obj:
        content = file_obj.readlines()
        for line in content:
            if not line.strip():
                continue
            try:
                filename =  os.path.basename(line).strip()
                download_to_local(line, filename)
                if (filename.endswith("zip")):
                    extract_zip_and_upload(filename, download_location)
                else:
                    upload_to_s3(filename, download_location)
                cmd = "rm " + filename
                get_shell_cmd_output(cmd)
            except Exception as cmdexception:
                sys.stderr.write("%s" % cmdexception)
                return False;
    return True;

if __name__ == "__main__":
    if (len(sys.argv) != 3):
        sys.stderr.write("Takes only two arguments - path to file with locations and s3 bucket\n")
        sys.exit(1)
    if(process_input(sys.argv[1], sys.argv[2])):
        sys.stdout.write("Upload succesful\n")
        sys.exit(0)
    sys.exit(1)
