# Migrating Files off an OST

There can be occasions when it is necessary to clear an OST.

Hardware upgrades, hardware replacement due to age or a fault.
Provided there is sufficient space left on the lustre file system, it can be possible to empty an OST by migrating files off it.

This ensures that the user's files are retained unharmed (if the OST works) and maintenance work may even be transparent to the user (except for some I/O performance loss).

## "Our" Process as Developed from Reading Manuals and Mailing List Discussions

> [!CAUTION]
> Be very careful when manipulating OSTs or admin functions on a lustre (or any) file system.
> In correct use carries a risk of data loss.
> Ideally back up your data (bit difficult with a typical lustre file system...) - and test the process on a test system (just a few VMs to replicate your configuration will do).
> Dry run code where possible and make sure you fully understand the implications of the actions you take, which are your responsibility alone.

So, warnings out of the way, on to the steps:

### To clear an OST, it is necessary to avoid writing new files to it

The common advice is to deactivate it on the metadata server (MDS).
The disadvantage of this is, that this will not result in the OST being cleared of data and inodes as files are migrated.
In current versions of lustre, it is possible to instead set the count for the creation of new fiels to zero instead.
This will prevent new files from being created, while allowing existing files to be migrated off the OST.

For this it is necessary to disable the OST on all (!!!) MDS.
Connect to the MDS and find the OSTs you wish to migrate, for example:

```bash
# find the active OSTs which gets their names
lctl get_param osc.*.active
# read the current value, so you can rest it later
lctl get_param osc.lustre-OST0000-osc-MDT0000.max_create_count
lctl get_param osc.lustre-OST0000-osc-MDT0000.create_count
# prevent writes to the OSTs you wish to migrate
lctl set_param osc.lustre-OST0000-osc-MDT0000.max_create_count=0
lctl set_param osc.lustre-OST0000-osc-MDT0001.max_create_count=0
# note that max_create_count=0 will also set create_count=0
lctl set_param osc.lustre-OST0000-osc-MDT0000.create_count=0
lctl set_param osc.lustre-OST0000-osc-MDT0001.create_count=0
```

The default values are `create_count=32` and `max_create_count=20000`.

Repeating myself, please not that the OSTs need to be disabled on all MDS!

### On to Find the Files on the OST

The next step consists of finding files on the OST to be migrated.
This is done from a client machine, from an account that is able to access all directories and files.
(root or a service account)
This is achieved with `lfs --find`

Here in this example, we would need to seek out the files on `OST0000` - and our test system is mounted under `/lustre/lustre`.
Because we need the file list to migrate files, we can write it to a file by redirecting the output:

```bash
lfs find --ost lustre-OST0000 /lustre/lustre > /lustre/lustre/files_OST0000.01
```

This now gives us a list of files that are entirely or partially (in case of striping) store on the OST.
Thus far, no files have been moved.

#### Scripting the process

While this runs within a reasonably short time frame on a test system, on our production system this process takes multiple hours.

Thus the process was packaged in a script, which can be updated and run in parallel (with GNU parallel) to write out the files on the OST.

This is in  [find_files_on_ost_in_parallel.bash](find_files_on_ost_in_parallel.bash).

### Migrating the Files

In the last step, we can move the files.
As `lfs_migrate` moves a single file and we have a list of files in a text file, the easiest approach is to loop over the list of files in the text file using some simple bash functions.

The following script takes the file list as an argument and will run `lfs_migrate` on every file in the list:

```bash
#!/bin/bash

## launch with fiThis is in  [find_files_on_ost_in_parallel.bash](find_files_on_ost_in_parallel.bash).le name as argument
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
```

Note: It is also possible to use `lfs_migrate` to stripe large files over multiple OSTs if necessary.
Here files (or stripes) are moved in their entirety to another active OST that accepts new files.

#### Scripting the migration

Similar to the file discovery, the migration can also be scripted, as it once again runs fast on a test setup, but can take a significant amount of time on a large file system, depending on file volume in terms of size and count.

Furthermore, it may be advisable to "chunk" the work into steps to speed up the process.
If one OST contains significantly more files than another, the process may take a lot longer and be bottlenecked by the serial nature of the file migration process.
Thus the source lists are first split into smaller sized jobs that can then be processed individually by GNU parallel, speeding up the process.

This is in  [migrate_files_on_ost_in_parallel.bash](migrate_files_on_ost_in_parallel.bash).
