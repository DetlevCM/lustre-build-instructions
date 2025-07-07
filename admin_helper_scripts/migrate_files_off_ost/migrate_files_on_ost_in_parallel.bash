#!/bin/bash

if [ "$1" == "" ];
then
  echo ""
  echo "This script must be given the file name or file name pattern"
  echo "for a text file that lists the files on an OST to be migrated."
  echo ""
  echo "For example the two following calls are valid:"
  echo "migrate_files_on_ost_in_parallel.bash files_OST0001 "
  echo "migrate_files_on_ost_in_parallel.bash \"files_OST000*\" "
  echo ""
  echo "In the second case, the wildcard asterisk will be expanded."
  echo "Optional 2nd and 3rd arguments are the number of entries to"
  echo "process per parallel threads (default 100000) and the "
  echo "number fo parallel threads to use (default 8)."
  echo ""
  exit 0
fi

## add gnu parallel
## here it is built in a known path/location, thus hardcoded in the script
source ./parallel-20250622/src/env_parallel.bash
export PATH=$PATH:/srv/prometheus/lustre_move/parallel-20250622/src


## give the base file for the OST as an argument to the script
## when providing a wildcard, the user must quote the pattern
BaseFile=$1
## default 1000000 files per file, adjust as required
LinesPerFile=${2:-100000}
## default number of threads to use, here set to, or use optional argument
NumberParallelThreads=${3:-8}


## the user may provide a single file or a file pattern with an asterisk
## a file pattern MUST be supplied as a string in quotation marks

# $BaseFile needs to expand the asterisk here
for File in $BaseFile
do
  echo $File
  TmpDir="tmp_split/$File"
  #TmpDir="tmp_parallel/$File"
  rm -rf $TmpDir
  mkdir -p $TmpDir

  split -l $LinesPerFile $File --numeric-suffixes --suffix-length=6 "$TmpDir/$File."
done


## function to process the base files:
function migrate_files(){

## launch with file name as argument
File=$1

if [ "$File" == "" ];
then
  echo "no name for file list file passed, error"
  exit 1
fi

## https://stackoverflow.com/questions/19838064/bash-determine-if-variable-is-empty-and-if-so-exit
## loop over the file containing one file per line
while read $p; do
    lfs_migrate -y $p
done <"$File"

}

## export the function so it is accessible to gnu parallel
export -f migrate_files

## https://stackoverflow.com/questions/45830277/gnu-parallel-to-parallelize-a-for-loop

ls -d tmp_split/*/*.* | parallel --jobs $NumberParallelThreads migrate_files

