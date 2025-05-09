
# Lustre Server

## Rocky 9.4 Installation

The first step consists of setting up a (virtual machine).
In the case of Rocky 9.4  there should not be a requirement for any special settings, contrary to 8.10 networking should work right away.

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

The oprtating system can be intalled and further steps continue after installation.

## Preparation

To compile both the kernel and the lustre server, a number of additional packages are required.
The largest set is taken from an online tutorial and may thus be more expansive than necessary.
It should be noted that the "powertools" in Rocky 8 have become "crb" ("code ready builder") from Rocky 9 onward.

Assuming you are root:

```
yum -y groupinstall "Development Tools"
```

Followed by:

```
yum config-manager --set-enabled crb
dnf install -y gcc autoconf libtool which make patch diffutils file binutils-devel python38 python3-devel elfutils-devel libselinux-devel libaio-devel dnf-plugins-core bc bison flex git libyaml-devel libnl3-devel libmount-devel json-c-devel redhat-lsb libssh-devel libattr-devel libtirpc-devel libblkid-devel openssl-devel libuuid-devel texinfo texinfo-tex
yum -y install audit-libs-devel binutils-devel elfutils-devel kabi-dw ncurses-devel newt-devel numactl-devel openssl-devel pciutils-devel perl perl-devel python2 python3-docutils xmlto xz-devel elfutils-libelf-devel libcap-devel libcap-ng-devel llvm-toolset libyaml libyaml-devel kernel-rpm-macros kernel-abi-whitelists opencsd-devel
dnf install -y epel-release
dnf install -y ccache pdsh
```

Note: `resource-agents` available on Rocky 8.10 are not available nor required.

```
dnf install -y bpftool dwarves java-devel libbabeltrace-devel libbpf-devel libmnl-devel net-tools rsync
# May only be needed on RHEL9 derivatives:
dnf install -y python3-devel
```


Following the initial batch of packages, compilation attempts will identify further missing packages that are required.
We add these next, this is the list from Rocky 8.10:

```
dnf install audit-libs-devel clang kabi-dw libcap-devel libcap-ng-devel libtraceevent-devel llvm ncurses-devel newt-devel numactl-devel pciutils-devel python3-docutils system-sb-certs xmlto
```

Followed by additional packages required on Rocky 9.4, first for the kernel and then lustre server:

```
dnf install -y WALinuxAgent-cvm gcc-plugin-devel glibc-static kernel-rpm-macros perl-devel systemd-boot-unsigned
dnf install -y dnf install libnl3 libnl3-devel libyaml libyaml-devel
```




## e2fsprog (patched)

As lustre requires modified e2fsprogs, these need to be downloaded from the whamcloud repo:

```
git clone "https://review.whamcloud.com/tools/e2fsprogs" e2fsprogs
```

While it may be tempting to pick the latest release, it is necessary to use a version that includes patches to make it lustre compatible.
The version proposed in the tutorial is `v1.47.0-wc1`, it can be selected as follows from the `e2fsprogs` directory.
(Tested 2024/10)

```
cd e2fsprogs
git checkout v1.47.0-wc1
```

In the directory, we can then configure the build.
The configuration has been copied over from the source tutorial, except for the removal of `--enable-quota` which is not recognised.

```
./configure --with-root-prefix=/usr --enable-elf-shlibs --disable-uuidd --disable-fsck --disable-e2initrd-helper --disable-libblkid --disable-libuuid --disable-fuse2fs
```

Provided the configuration finished successfully, we can now build the code and install it.

```
make 
make install
```

It is possible to build rpm packages with `make rpm`, however this results in an error in root acls during in one fo the tests when an unpatched kernel is employed.
In addition, the interdependencies between packages create additional complications, thus building the rpm packages was not further explored as this stage and is not part of this set of instructions.

As the original tutorial employs a binary installation, this is the recommended path. 





## lustre & the patched kernel

### download lustre

The next step consists of first cloning the lustre source code repository:

```
git clone "https://review.whamcloud.com/fs/lustre-release"
```

*Note:*
*At the time of writing (2024/10), the master branch of the code was used.*
*This corresponds to lustre 2.16-RC1. In thef future it may be necessary to selecte a specific tag.*

The configuration scripts for the lustre source code are prepared using `autogen.sh`

```
cd lustre-release
sh ./autogen.sh
```

### prepare patched kernel

Before the lustre server can be buult and installed, is is necessary to prepare a patched kernel and install it first.

Contrary to the original source, it is easier to download the src.rpm package using dnf.
This further removes reliance on kernel source rpms hosted by a third party.
Simultaneously, the use of unsupported kernels first lustre is obviously at the user's own risk.

```
cd
dnf download --source kernel
```

Next we can prepare the directory structure for rpmbuild (it may even do this automatically):

```
mkdir -p kernel/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd kernel && echo '%_topdir %(echo $HOME)/kernel/rpmbuild' > ~/.rpmmacros
```

This allows us to install the kernel sources from the local src.rpm.
As this is Rocky 9.4, the kernel version numbers will now diverge from those in the original source for 8.7.
The version employed here is/was valid at the time of setting up and may change as a result of updates.
(2024/10)

Install the kernel into the build tree:

```
rpm -ivh kernel-5.14.0-427.37.1.el9_4.src.rpm
```

Next, following the tutorial, we prepare the kernel:

```
cd ~/kernel/rpmbuild && rpmbuild -bp --target=`uname -m` ./SPECS/kernel.spec
```

To build the patches specific to the kernel, we now copy the kernel configuration file into the lustre source code repository, overwriting any potentially existing files.


```
cp \
~/kernel/rpmbuild/BUILD/kernel-5.14.0-427.37.1.el9_4/linux-5.14.0-427.37.1.el9.`uname -m`/configs/kernel-5.14.0-`uname -m`.config \
~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config
```

Then we need to add two lines to the kernel config file in the lustre repository for the IO Scheduler, required for lustre:

CONFIG_IOSCHED_DEADLINE=y
CONFIG_DEFAULT_IOSCHED="deadline"

Which can be achieved via the proposed command line as follows:

```
sed -i '/# IO Schedulers/a CONFIG_IOSCHED_DEADLINE=y\nCONFIG_DEFAULT_IOSCHED="deadline"' ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config
```

The lustre source code provides a series of patches that become more extensive as the kernel develops.
These can be, as per the tutorial, collected into a single file.
The tutorial limited the kernel range to rhel8.7-series, which was adapted to include rehel9.4-series for rocky 9.4 support.

Thus the line becomes the following:

```
cd ~/lustre-release/lustre/kernel_patches/series && \
for patch in $(<"5.14-rhel9.4.series"); do \
     patch_file="$HOME/lustre-release/lustre/kernel_patches/patches/${patch}"; \
     cat "${patch_file}" >> "$HOME/lustre-kernel-`uname -m`-lustre.patch"; \
done
```

The collated patch can then be copied from the lustre source directory into the rpm build tree giving us the prepared configuration for the patched kernel:

```
cp ~/lustre-kernel-`uname -m`-lustre.patch ~/kernel/rpmbuild/SOURCES/patch-5.14.0-lustre.patch
```


Next the kernel.spec file under kernel/rpmbuild/SPECS/kernel.spec needs to be edited...
The line is taken from the tutorial without change.

```
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


```
echo '# x86_64' > ~/kernel/rpmbuild/SOURCES/kernel-`uname -m`.config
cat ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config >> ~/kernel/rpmbuild/SOURCES/kernel-`uname -m`.config
```

#### build patched kernel

And now we can finally start to build the kernel:

```
cd ~/kernel/rpmbuild && buildid="_lustre" && \
rpmbuild -ba --with firmware --target `uname -m` --with baseonly \
           --without kabichk --define "buildid ${buildid}" \
           ~/kernel/rpmbuild/SPECS/kernel.spec

```

#### install patched kernel

Once successfully built, we can then install the new kernel and reboot the system.

```
cd ~/kernel/rpmbuild/RPMS/`uname -m`/
sudo rpm -Uvh --replacepkgs --force kernel-*.rpm
sudo reboot
```

After the reboot it is possible to verify that the newly installed kernel has been loaded by running the following command:

```
uname -r
```


#### Notes:

Manty of the commands add content to files.
As a result it is not advised to rerun commands.
IF at any step during the process steps fails, analyze the failure and return to the original source rpm package and retrace the steps.


#### Notes 27 Nov 2024:

additional required package for kernel
```dnf install systemd-ukify```

additional required packages for lustre
```dnf install libnl3-devel.x86_64```
```dnf install libyaml-devel.x86_64```

### build lustre

As the underlying operating system is now prepared, the lustre server can now be built and installed.
We configure lustre while pointing it at the kernel source code that was employed to build the patched kernel.
An important caveat is that as a local test VM, the kernel was built as root under /root, not necessarily a recommended approach.

**it is possible something went wrong with the naming somewhere as the naming pattern changed, but this works...**

```
cd lustre-release
./configure --with-linux=/root/kernel/rpmbuild/BUILD/kernel-5.14.0-427.37.1.el9_4/linux-5.14.0-427.37.1_lustre.el9.`uname -m`/ --disable-gss --disable-shared --disable-crypto
```












































Now the lustre server can be built and installed:

```
make
sudo make install
sudo depmod -a
```


### run and test lustre locally

*Note:*
*A Rocky 9.4 quirk is that the test script will not work by default.*
*This possibly loops back to some checks in the script and running it will lead to an error...*
*It turns out, this error is related to the hostname.*

*Not ideal, but for a local vm it works, set the hostname to `localhost`:*

```
hostnamectl set-hostname localhost
```

Then continue as usual, we launch a test instance via the tutorial recommended script :
```
/usr/lib64/lustre/tests/llmount.sh
```

When successful, the should be similar to this:

```
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














