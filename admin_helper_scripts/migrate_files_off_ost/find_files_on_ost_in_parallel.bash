#!/bin/bash

## find files running something like:
# lfs find --ost lustre-OST0008 /mnt/lustre > /srv/prometheus/lustre_move/files_OST0008.01
## to split the work for running in parallel, do:
# split -l 10000 files_OST0002.01 --numeric-suffixes --suffix-length=6 files_OST0002.01.


## add gnu parallel
## here it is built in a known path/location, thus hardcoded in the script
source ./parallel-20250622/src/env_parallel.bash
export PATH=$PATH:/srv/prometheus/lustre_move/parallel-20250622/src

## define the number of parallel threads to use when searching for files, 
## can be the same as the OSTs in question
NumberParallelThreads=8

## list of OSTs on which to search for files
test_list=( "lustre-OST0008" "lustre-OST0009" "lustre-OST000a" "lustre-OST000b" "lustre-OST000c" "lustre-OST000d" "lustre-OST000e" "lustre-OST000f" )

## just a counter label on the file name
run_number="03"

## paths to lustre and the directory in which to write the results
lustre_mount_dir="/mnt/lustre"
lfs_find_log_dir="/srv/prometheus/lustre_move"


## package the file search with lfs_find in a function
function find_files_on_ost()
{

lustre_mount_dir=$1
lfs_find_log_dir=$2
run_number=$3

ost_name=$4

echo "${lfs_find_log_dir}/${ost_name}.${run_number}"

lfs find --ost $ost_name $lustre_mount_dir > "${lfs_find_log_dir}/${ost_name}.${run_number}"

}

## export the function so it is accessible to gnu parallel
export -f find_files_on_ost

## run the function using GNU parallel
parallel --jobs $NumberParallelThreads find_files_on_ost "$lustre_mount_dir" "$lfs_find_log_dir" "$run_number" ::: ${test_list[@]}

