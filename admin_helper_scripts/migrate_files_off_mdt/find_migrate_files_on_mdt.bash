#!/bin/bash

# Really not worth putting into a script, lfs find can find 
# which files are stored on a specific mdt with a known index 
# number, on a specific lustre file system.
#
# For further work with the files, such as migrating, it is 
# useful to stream the results to a file. 
#
# The process can take a long time and write large files.
# The list will contain files on the mdt, however the mdt migration
# scripts move directories if I understand things correctly.

lfs find --mdt-index 1 /mnt/lustre > mdt_log.01.txt

# migration is then carried out by migrating to a specific mdt a specific 
# directory, such as for example

lfs migrate -m 0 /mnt/lustre/scratch

# The process will fail for files that are open/in use and sometimes fail 
# for other unknown reasons. In this case, it can be useful to descend into 
# a directory and migrate the subdirectory.
# For example by building something like the following loop:

CurrentDir=$(pwd)
for Dir1 in */ ;
do
  cd $CurrentDir/$Dir1
  for Dir2 in */ ;
  do
    cd $CurrentDir/$Dir1/$Dir2
    for Dir3 in */ ;
    do
      lfs migrate -m 0  $Dir3
    done
    lfs migrate -m 0  $Dir2
  done
  lfs migrate -m 0  $Dir1
done
cd $CurrentDir

# This will throw errors if the loop depth cannot be reached. 
