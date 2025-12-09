# Reconfiguring our MDT - It worked, don't do it (Unless you really know what you are doing and can afford to lose data)

> [!CAUTION]
> Changing the MDT carries an inherent risk.
> The risk of losing some, or more likely all data is quite high.
> This process has worked for us, neither I nor the team I am part of can endorse this approach.
> This documentation is meant as an experience report, any decisions that follow are your own.

## Backstory

Due to how things worked out, the service provider that configured our lustre chose a suboptimal configuration from a performance perspective.
(Hence the OST reconfiguration discussed in parallel.)
In addition to the suboptimal configuration, we expanded the metadata targets in order to be able to support the DoM, Data on Metadata( target) of Lustre.

This process necessitates reconfiguring the entire underlying storage architecture of the metadata target.
While officially a test system in small scale production use, our infrastructure benefits from a fairly modest size and at present not excessively huge size, which permitted the following approach.
(About 83GB of actual space used and 194 Million inodes used on the MDTs.)
This would be less feasible, or potentially impossible on a larger scale production system - or involve significant downtime.

## Steps

### Preparation

- When the decision was made to reconfigure the MDTs, the first step was to consolidate all metadata on a single MDT.
To do so, the MDTs were set to disallow the creation of new entries on the metadata servers: `lctl set_param mdt.lustre-MDT0001.no_create=1`
They are not deactivated, as this allows for the removal of entries as files are migrated over to other MDTs.
As with all lctl parameters, these are not persistent over a reboot.
- Once the MDTs were disabled, entries on the disabled MDTs were sought using `lfs find --mdt-index 1 /mnt/lustre > mdt_log.01.txt`, and then migrated by pointing `lfs migrate -m 0` at the directories, directly but also using loops that would descend into subdirectories which resolved some migration issues.
This was carried out repeatedly, including the search, to whittle the number of "migration issues" to a number that could be handled separately.
As files that are in use cannot be migrated, it may be necessary to wait until jobs finish to migrate some files or to contact users about creating new directories and/or copies of files that they work from, in order to permit the migration to complete successfully.
- Certain files cannot be migrated, effectively due to user error (file names that contain a single backslash for example...); these can however be recreated using tools such as `cp` and `rsync`, where a new file receives a new inode.
Then the old file can be switched to the new and the old file removed (or moved to a root only storage area for temporary safekeeping).

These steps were repeated, until `lfs find` confirmed that no files were stored on an MDT other than MDT0000.
While the approach concentrated the files on one MDT, realistically there is no obvious reason why it should not be possible to use an arbitrary number of MDTs in this process.
One side aspect of our reconfiguration was the reduction from 4 MDTs down to 2 for easier management (at our scale).

### Migration and Reconfiguration

This scenario was tested in a virtual machine before being used in production.
It worked, however carries risks.
THe lustre file system was taken offline for maintenance in this step.

- A temporary volume was formatted as a lustre metadata target, using MDT0000 as an index.
- The volume, as well as the original MDT0000 were mounted as type `ldiskfs`, which si the patched ext4 file system used in lustre. - It is important to ensure the new drive has sufficient space and inodes. Using a system resilient against hardware failure (Raid 1, 5, 6 etc.) is recommended.
- Data was copied from the original MDT to the new volume. Options are `cp -a` `rsync --xattr`, in our case rsync was used in production.
This copied all entries over to the temporary/or new volume.
- Once the copy was complete, the volumes were unmounted and all lustre volume indices rewritten using writeconf.
- The temporary volume was mounted to verify it is usable. (Worked!)
- In our case, we then unmounted all volumes, reconfigured the original storage target, erasing existing volumes and then repeated the procedure, writing data to the production use system.
