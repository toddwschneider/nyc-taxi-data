#!/usr/bin/env python

import os
import sys

def do_convert(fullpath):
    file_name = os.path.basename(fullpath)
    new_file_name = "s3_" + file_name
    with open(fullpath) as file_obj:
        content = file_obj.readlines()
        newcontent = ""
        for line in content:
            # https://s3.amazonaws.com/nyc-tlc/trip+data/fhv_tripdata_2015-01.csv
            index = line.find("s3.amazonaws.com") + len("s3.amazonaws.com")
            new_line = "\"s3://" + line[index+1 : len(line)-1] + "\"\n"
            new_line = new_line.replace('+',' ')
            newcontent+=new_line
    with open(new_file_name, "w") as file_obj:
        file_obj.write(newcontent)
        return True
    return False

if __name__ == "__main__":
    if (len(sys.argv) != 2):
        sys.stderr.write("Takes only one argument - the file name with http Urls to s3 buckets\n")
        sys.exit(1)
    if(do_convert(sys.argv[1])):
        sys.stdout.write("Conversion succesful\n")
        sys.exit(0)
    sys.stderr.write("Something went wrong\n")
    sys.exit(1)
