<!-- https://github.com/DavidAnson/markdownlint/blob/v0.37.4/doc/md010.md -->
<!-- markdownlint-configure-file { "MD010": { "code_blocks": false } } -->

# Lustre Server

## Rocky 8.10 Installation

The first step consists of setting up a (virtual machine).
In the case of Rocky 8.10, it was found that networking needs to be manually enabled during the installation process as the default is disabled.

### Hardware Configuration

The lazy choice is to use a single disk.
The size chosen was 70GB to ensure sufficient space for the kernel compilation leaving plenty of space to spare.
At least 36GB of space are required just for installation, sources and compilation files.
It is also possible to use a smaller root disk and a data partition.

2 threads or 4 threads (1/2 cores) are sufficient, as are 3072MB of RAM.
Of course a more performant virtual machine will compile the server faster.

The networking employed is "NAT", network address translation, which is well suited to local tests.

### Installation Settings

- the Server profile (no GUI) is selected.

Additional Software Selected:

- Development Tools
- RPM development tools

As a lazy option only the root user is configured.
**Warning, this is a lazy option for testing in a VM.**

A single partition is used.

The operating system can be installed and further steps continue after installation.

## Preparation

To compile both the kernel and the lustre server, a number of additional packages are required.
The largest set is taken from an online tutorial and may thus be more expansive than necessary.
It should be noted that the "powertools" in Rocky 8 have become "crb" ("code ready builder") from Rocky 9 onward.

Assuming you are root:

```bash
yum -y groupinstall "Development Tools"
```

Followed by:

```bash
yum config-manager --set-enabled powertools
dnf install -y gcc autoconf libtool which make patch diffutils file binutils-devel python38 python3-devel elfutils-devel libselinux-devel libaio-devel dnf-plugins-core bc bison flex git libyaml-devel libnl3-devel libmount-devel json-c-devel redhat-lsb libssh-devel libattr-devel libtirpc-devel libblkid-devel openssl-devel libuuid-devel texinfo texinfo-tex
yum -y install audit-libs-devel binutils-devel elfutils-devel kabi-dw ncurses-devel newt-devel numactl-devel openssl-devel pciutils-devel perl perl-devel python2 python3-docutils xmlto xz-devel elfutils-libelf-devel libcap-devel libcap-ng-devel llvm-toolset libyaml libyaml-devel kernel-rpm-macros kernel-abi-whitelists opencsd-devel
dnf install -y epel-release
dnf install -y ccache pdsh
dnf --enablerepo=ha install resource-agents
```

```bash
dnf install -y bpftool dwarves java-devel libbabeltrace-devel libbpf-devel libmnl-devel net-tools rsync
# May only be needed on RHEL9 derivatives:
dnf install -y python3-devel
```

Following the initial batch of packages, compilation attempts will identify further missing packages that are required.
We add these next, this is the list for Rocky 8.10:

```bash
dnf install audit-libs-devel clang kabi-dw libcap-devel libcap-ng-devel libtraceevent-devel llvm ncurses-devel newt-devel numactl-devel pciutils-devel python3-docutils system-sb-certs xmlto
```

## e2fsprog (patched)

As lustre requires modified e2fsprogs, these need to be downloaded from the whamcloud repo:

```bash
git clone "https://review.whamcloud.com/tools/e2fsprogs" e2fsprogs
```

While it may be tempting to pick the latest release, it is necessary to use a version that includes patches to make it lustre compatible.
The version proposed in the tutorial is `v1.47.0-wc1`, it can be selected as follows from the `e2fsprogs` directory.
(Tested 2024/10)

```bash
cd e2fsprogs
git checkout v1.47.0-wc1
```

In the directory, we can then configure the build.
The configuration has been copied over from the source tutorial, except for the removal of `--enable-quota` which is not recognized.

```bash
./configure --with-root-prefix=/usr --enable-elf-shlibs --disable-uuidd --disable-fsck --disable-e2initrd-helper --disable-libblkid --disable-libuuid --disable-fuse2fs
```

Provided the configuration finished successfully, we can now build the code and install it.

```bash
make 
make install
```

It is possible to build rpm packages with `make rpm`, however this results in an error in root acls during in one fo the tests when an unpatched kernel is employed.
In addition, the interdependencies between packages create additional complications, thus building the rpm packages was not further explored as this stage and is not part of this set of instructions.

As the original tutorial employs a binary installation, this is the recommended path.

## lustre & the patched kernel

### download lustre

The next step consists of first cloning the lustre source code repository:

```bash
git clone "https://review.whamcloud.com/fs/lustre-release"
```

*Note:*
*At the time of writing (2024/10), the master branch of the code was used.*
*This corresponds to lustre 2.16-RC1. In the future it may be necessary to select a specific tag.*

The configuration scripts for the lustre source code are prepared using `autogen.sh`

```bash
cd lustre-release
sh ./autogen.sh
```

### prepare patched kernel

Before the lustre server can be built and installed, is is necessary to prepare a patched kernel and install it first.

Contrary to the original source, it is easier to download the src.rpm package using dnf.
This further removes reliance on kernel source rpms hosted by a third party.
Simultaneously, the use of unsupported kernels first lustre is obviously at the user's own risk.

```bash
cd 
dnf download --source kernel
```

Next we can prepare the directory structure for rpmbuild (it may even do this automatically):

```bash
mkdir -p kernel/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd kernel && echo '%_topdir %(echo $HOME)/kernel/rpmbuild' > ~/.rpmmacros
```

This allows us to install the kernel sources from the local src.rpm.
As this is Rocky 8.10, the kernel version numbers will now diverge from those in the original source for 8.7.
The version employed here is/was valid at the time of setting up and may change as a result of updates.
(2024/10)

Install the kernel into the build tree:

```bash
rpm -ivh kernel-4.18.0-553.22.1.el8_10.src.rpm
```

Next, following the tutorial, we prepare the kernel:

```bash
cd ~/kernel/rpmbuild && rpmbuild -bp --target=`uname -m` ./SPECS/kernel.spec
```

To build the patches specific to the kernel, we now copy the kernel configuration file into the lustre source code repository, overwriting any potentially existing files.

```bash
cp \
~/kernel/rpmbuild/BUILD/kernel-4.18.0-553.22.1.el8_10/linux-4.18.0-553.22.1.el8.`uname -m`/configs/kernel-4.18.0-`uname -m`.config \
~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-4.18.0-4.18-rhel8.10-`uname -m`.config
```

Then we need to add two lines to the kernel config file in the lustre repository for the IO Scheduler, required for lustre:

CONFIG_IOSCHED_DEADLINE=y
CONFIG_DEFAULT_IOSCHED="deadline"

Which can be achieved via the proposed command line as follows:

```bash
sed -i '/# IO Schedulers/a CONFIG_IOSCHED_DEADLINE=y\nCONFIG_DEFAULT_IOSCHED="deadline"' ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-4.18.0-4.18-rhel8.10-`uname -m`.config
```

The lustre source code provides a series of patches that become more extensive as the kernel develops.
These can be, as per the tutorial, collected into a single file.
The tutorial limited the kernel range to rhel8.7-series, which was adapted to include rhel8.10-series for rocky 8.10 support.

Thus the line becomes the following:

```bash
cd ~/lustre-release/lustre/kernel_patches/series && \
for patch in $(<"4.18-rhel8.10.series"); do \
     patch_file="$HOME/lustre-release/lustre/kernel_patches/patches/${patch}"; \
     cat "${patch_file}" >> "$HOME/lustre-kernel-`uname -m`-lustre.patch"; \
done
```

The collated patch can then be copied from the lustre source directory into the rpm build tree giving us the prepared configuration for the patched kernel:

```bash
cp ~/lustre-kernel-`uname -m`-lustre.patch ~/kernel/rpmbuild/SOURCES/patch-4.18.0-lustre.patch
```

Next the kernel.spec file under kernel/rpmbuild/SPECS/kernel.spec needs to be edited...
The line is taken from the tutorial without change.

```bash
sed -i.inst -e '/^    find $RPM_BUILD_ROOT\/lib\/modules\/$KernelVer/a\
    cp -a fs/ext4/* $RPM_BUILD_ROOT/lib/modules/$KernelVer/build/fs/ext4\
    rm -f $RPM_BUILD_ROOT/lib/modules/$KernelVer/build/fs/ext4/ext4-inode-test*' \
-e '/^# empty final patch to facilitate testing of kernel patches/i\
Patch99995: patch-%{version}-lustre.patch' \
-e '/^ApplyOptionalPatch linux-kernel-test.patch/i\
ApplyOptionalPatch patch-%{version}-lustre.patch' \
~/kernel/rpmbuild/SPECS/kernel.spec
```

Now the kernel config file is written to a `kernel-arch.config` file as per the original source.

```bash
echo '# x86_64' > ~/kernel/rpmbuild/SOURCES/kernel-`uname -m`.config
cat ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-4.18.0-4.18-rhel8.10-`uname -m`.config >> ~/kernel/rpmbuild/SOURCES/kernel-`uname -m`.config
```

#### build patched kernel

And now we can finally start to build the kernel:

```bash
cd ~/kernel/rpmbuild && buildid="_lustre" && \
rpmbuild -ba --with firmware --target `uname -m` --with baseonly \
           --without kabichk --define "buildid ${buildid}" \
           ~/kernel/rpmbuild/SPECS/kernel.spec

```

#### install patched kernel

Once successfully built, we can then install the new kernel and reboot the system.

```bash
cd ~/kernel/rpmbuild/RPMS/`uname -m`/
sudo rpm -Uvh --replacepkgs --force kernel-*.rpm
sudo reboot
```

After the reboot it is possible to verify that the newly installed kernel has been loaded by running the following command:

```bash
uname -r
```

#### Notes

Many of the commands add content to files.
As a result it is not advised to rerun commands.
IF at any step during the process steps fails, analyze the failure and return to the original source rpm package and retrace the steps.

### build lustre

As the underlying operating system is now prepared, the lustre server can now be built and installed.
We configure lustre while pointing it at the kernel source code that was employed to build the patched kernel.
An important caveat is that as a local test VM, the kernel was built as root under /root, not necessarily a recommended approach.

>
> #### Note
>
> Between the initial draft of this document and now (2024_10_18) the kernel version of Rocky 8.10 changed from 4.18.0-553.22 to 4.18.0-553.16.
> This guide was written initially written for the .22 version.
> sIn the .18 version tested later, there is/was no longer any need to modify the patch file and paths during the build of the kernel should be adjusted accordingly.
>

```bash
cd lustre-release
./configure --with-linux=/root/kernel/rpmbuild/BUILD/kernel-4.18.0-553.22.1.el8_10/linux-4.18.0-553.22.1.el8_lustre.`uname -m`/ --disable-gss --disable-shared --disable-crypto
```

Normally we could now build lustre, however the ext4 source has changed in this specific kernel and as a result of the patching now fails.
To successfully build lustre, we need to adjust the patch file to be compatible with the current ext4 source.
The patch file is `/root/lustre-release/ldiskfs/kernel_patches/patches/base/ext4-delayed-iput.patch`.

Here we need to remove `struct inode *new_ea_inode = NULL;` and `iput(new_ea_inode);` adjusting the number of expected lines accordingly.
The adjusted patch (at the end of the patch file), thus now looks as follows:

```bash
 /*
  * Reserve min(block_size/8, 1024) bytes for xattr entries/names if ea_inode
  * feature is enabled.
@@ -1561,5 +1591,6 @@ static int ext4_xattr_set_entry(struct ext4_xattr_info *i,
 	int in_inode = i->in_inode;
 	struct inode *old_ea_inode = NULL;
+	struct delayed_iput_work *diwork = NULL;
 	size_t old_size, new_size;
 	int ret;

@@ -1637,7 +1668,11 @@ static int ext4_xattr_set_entry(struct ext4_xattr_info *i,
 	 * Finish that work before doing any modifications to the xattr data.
 	 */
 	if (!s->not_found && here->e_value_inum) {
-		ret = ext4_xattr_inode_iget(inode,
+		diwork = kmalloc(sizeof(*diwork), GFP_NOFS);
+		if (!diwork)
+			ret = -ENOMEM;
+		else
+			ret = ext4_xattr_inode_iget(inode,
 					    le32_to_cpu(here->e_value_inum),
 					    le32_to_cpu(here->e_hash),
 					    &old_ea_inode);
@@ -1790,6 +1825,6 @@ static int ext4_xattr_set_entry(struct ext4_xattr_info *i,

 	ret = 0;
 out:
-	iput(old_ea_inode);
+	delayed_iput(old_ea_inode, diwork);
 	return ret;
 }
 --
2.25.1
```

Now the lustre server builds successfully and can be installed:

```bash
make
sudo make install
sudo depmod -a
```

### run and test lustre locally

We launch a test instance via the tutorial recommended script :

```bash
/usr/lib64/lustre/tests/llmount.sh
```

When successful, the should be similar to this:

```bash
mgs: Rocky Linux release 8.10 (Green Obsidian)
MGS_OS_ID_LIKE=rhel centos fedora rocky
MGS_OS_VERSION_ID=8.10
MGS_OS_ID=rocky
MGS_OS_VERSION_CODE=134873088
mds1: Rocky Linux release 8.10 (Green Obsidian)
MDS1_OS_VERSION_ID=8.10
MDS1_OS_VERSION_CODE=134873088
MDS1_OS_ID_LIKE=rhel centos fedora rocky
MDS1_OS_ID=rocky
ost1: Rocky Linux release 8.10 (Green Obsidian)
OST1_OS_VERSION_CODE=134873088
OST1_OS_ID_LIKE=rhel centos fedora rocky
OST1_OS_VERSION_ID=8.10
OST1_OS_ID=rocky
client: Rocky Linux release 8.10 (Green Obsidian)
CLIENT_OS_ID=rocky
CLIENT_OS_VERSION_CODE=134873088
CLIENT_OS_VERSION_ID=8.10
CLIENT_OS_ID_LIKE=rhel centos fedora rocky
Stopping clients: localhost.localdomain /mnt/lustre (opts:-f)
Stopping clients: localhost.localdomain /mnt/lustre2 (opts:-f)
localhost.localdomain: executing set_hostid
Loading modules from /usr/lib64/lustre/tests/..
detected 4 online CPUs by sysfs
Force libcfs to create 2 CPU partitions
gss/krb5 is not supported
Formatting mgs, mds, osts
Format mds1: /tmp/lustre-mdt1
Format ost1: /tmp/lustre-ost1
Format ost2: /tmp/lustre-ost2
Checking servers environments
Checking clients localhost.localdomain environments
Loading modules from /usr/lib64/lustre/tests/..
detected 4 online CPUs by sysfs
Force libcfs to create 2 CPU partitions
gss/krb5 is not supported
Setup mgs, mdt, osts
Starting mds1: -o localrecov  /dev/mapper/mds1_flakey /mnt/lustre-mds1
Commit the device label on /tmp/lustre-mdt1
Started lustre-MDT0000
Starting ost1: -o localrecov  /dev/mapper/ost1_flakey /mnt/lustre-ost1
seq.cli-lustre-OST0000-super.width=65536
Commit the device label on /tmp/lustre-ost1
Started lustre-OST0000
Starting ost2: -o localrecov  /dev/mapper/ost2_flakey /mnt/lustre-ost2
seq.cli-lustre-OST0001-super.width=65536
Commit the device label on /tmp/lustre-ost2
Started lustre-OST0001
Starting client: localhost.localdomain:  -o user_xattr,flock 192.168.122.50@tcp:/lustre /mnt/lustre
Using TIMEOUT=20
osc.lustre-OST0000-osc-ffff93fa30a24000.idle_timeout=debug
osc.lustre-OST0001-osc-ffff93fa30a24000.idle_timeout=debug
setting jobstats to procname_uid
Setting lustre.sys.jobid_var from disable to procname_uid
Waiting 90s for 'procname_uid'
disable quota as required
```
