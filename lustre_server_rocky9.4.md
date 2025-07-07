# Lustre Server on Rocky 9.4 - Updated 2025.05.09

## Structure

- set up Rocky Linux 9.4 (iso)
- download and install required packages
- download specific versions of packages from rocky vault and install
- download the source code for e2fsprogs, lustre and select version
- start building and installing from source code: e2fsprogs, kernel, lustre

# Rocky 9.4 Installation & Preparation

The first step consists of setting up a (virtual machine).
In the case of Rocky 9.4  there should not be a requirement for any special settings, contrary to 8.10 networking should work right away.

The iso file can be obtained from the Rocky Vault:

```bash
wget https://dl.rockylinux.org/vault/rocky/9.4/isos/x86_64/Rocky-9-latest-x86_64-dvd.iso
```

## Hardware Configuration

The lazy choice is to use a single disk.
The size chosen was 100GB to ensure sufficient space for the kernel compilation leaving plenty of space to spare.
At least 36GB of space are required just for installation, sources and compilation files.
It is also possible to use a smaller root disk and a data partition.

2 threads or 4 threads (1/2 cores) are sufficient, as are 3GB of RAM.
Of course a more performant virtual machine will compile the server faster, and RAM requirements scale with parallel builds.
4 threads benefit from 16GB of RAM.

The networking employed is "NAT", network address translation, which is well suited to local tests.

## Installation Settings

Rocky provides a set of default profiles as well as collections:

- the Server profile (no GUI) is selected.
- Development Tools,
- RPM development tools are selected.

As a lazy option only the root user is configured.
**Warning, this is a lazy option for testing in a VM.**

A single partition is used.

The operating system can be installed and further steps continue after installation.

## Preparation of Rocky 9.4

To compile both the kernel and the lustre server, a number of additional packages are required.
The largest set was initially taken from an online tutorial and may thus be more expansive than necessary.
It was then expanded to include the supplementary packages required on Rocky 9.4.
It should be noted that the "powertools" in Rocky 8 have become "crb" ("code ready builder") from Rocky 9 onward.

### Essential Packages

Assuming you are root:

```bash
yum -y groupinstall "Development Tools"
yum config-manager --set-enabled crb
```

```bash
dnf install -y gcc autoconf libtool which make patch diffutils file binutils-devel python38 python3-devel elfutils-devel libselinux-devel libaio-devel dnf-plugins-core bc bison flex git libyaml-devel libnl3-devel libmount-devel json-c-devel redhat-lsb libssh-devel libattr-devel libtirpc-devel libblkid-devel openssl-devel libuuid-devel texinfo texinfo-tex
dnf -y install audit-libs-devel binutils-devel elfutils-devel kabi-dw ncurses-devel newt-devel numactl-devel openssl-devel pciutils-devel perl perl-devel python2 python3-docutils xmlto xz-devel elfutils-libelf-devel libcap-devel libcap-ng-devel llvm-toolset libyaml libyaml-devel kernel-rpm-macros kernel-abi-whitelists opencsd-devel
dnf install -y epel-release
dnf install -y ccache pdsh
dnf install -y bpftool dwarves java-devel libbabeltrace-devel libbpf-devel libmnl-devel net-tools rsync
dnf install -y python3-devel
dnf install -y audit-libs-devel clang kabi-dw libcap-devel libcap-ng-devel libtraceevent-devel llvm ncurses-devel newt-devel numactl-devel pciutils-devel python3-docutils system-sb-certs xmlto
dnf install -y WALinuxAgent-cvm gcc-plugin-devel glibc-static kernel-rpm-macros perl-devel systemd-boot-unsigned
dnf install -y libnl3 libnl3-devel libyaml libyaml-devel
```

### For LustrePerfMon

```bash
dnf install -y libtool-ltdl libtool-ltdl-devel
```

### Support for Building RPM

To build the rpms - at least on 8.10 (when the issue was raised), one needs two more packages:

```bash
dnf install -y kernel-abi-stablelists.noarch lsb_release texinfo
```

### Version Specific Packages

The default packages installed by Rocky can be too new, ad the minor versions implicitly roll over.
At the time of writing (2025/05/09), only a specific kernel and libbpf and libbpf-devel need to be downloaded from the Rocky vault.
This list may change in the future!

### Downgrade libbpf to Match Kernel Version

```bash
cd 
wget https://dl.rockylinux.org/vault/rocky/9.4/devel/x86_64/os/Packages/l/libbpf-1.3.0-2.el9.x86_64.rpm
wget https://dl.rockylinux.org/vault/rocky/9.4/devel/x86_64/os/Packages/l/libbpf-devel-1.3.0-2.el9.x86_64.rpm

dnf install -y libbpf-*.rpm
```

### Downgrade Kernel to Use a Version Supported by Lustre (here the lastest supported version)

The original 9.4 iso comes with kernel 5.14.0-427.13.1.el9_4.
The latest supported kernel is 5.14.0-427.33.1.el9_4.
<!-- *check supported kernel... https://jira.whamcloud.com/browse/LU-18150* -->

```bash
cd
wget https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/x86_64/os/Packages/k/kernel-5.14.0-427.33.1.el9_4.x86_64.rpm
wget https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/source/tree/Packages/k/kernel-5.14.0-427.33.1.el9_4.src.rpm
wget https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/x86_64/os/Packages/k/kernel-core-5.14.0-427.33.1.el9_4.x86_64.rpm
wget https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/x86_64/os/Packages/k/kernel-modules-core-5.14.0-427.33.1.el9_4.x86_64.rpm
wget https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/x86_64/os/Packages/k/kernel-modules-5.14.0-427.33.1.el9_4.x86_64.rpm

dnf install -y \
kernel-core-5.14.0-427.33.1.el9_4.x86_64.rpm \
kernel-modules-5.14.0-427.33.1.el9_4.x86_64.rpm \
kernel-5.14.0-427.33.1.el9_4.x86_64.rpm \
kernel-modules-core-5.14.0-427.33.1.el9_4.x86_64.rpm
```

*Note: we do not install the src package!*

# Download the Sources

## e2fsprogs (patched) - Download

As lustre requires modified e2fsprogs, it need to be downloaded from the whamcloud repo:

```bash
cd
git clone "https://review.whamcloud.com/tools/e2fsprogs" e2fsprogs
```

While it may be tempting to pick the latest release, it is necessary to use a version that includes patches to make it lustre compatible.
The version proposed in the tutorial is `v1.47.0-wc1`, it can be selected as follows from the `e2fsprogs` directory, this build uses a later version available at the time of updating these instructions.

```bash
cd ~/e2fsprogs
git checkout v1.47.2-wc1
```

*Note: It may be necessary to check compatibility between e2fsprogs-wc and lustre releases!*

### Lustre - Download

The next step consists of first cloning the lustre source code repository:

```bash
cd
git clone "https://review.whamcloud.com/fs/lustre-release"
```

*Note:*
*As we copy files from and to the lustre source code, we should check out the version we intend to build before continuing:*

```bash
cd ~/lustre-release
git checkout 2.16.1
```

# Build e2fsprogs and Lustre

## e2fsprogs (patched) - Build and Install

The first step in building lustre, is to build the patched e2fsprogs.
Change to the source code directory and then configure the build.
The configuration has been copied over from the source tutorial, except for the removal of `--enable-quota` which is not recognized.

```bash
cd ~/e2fsprogs
./configure --with-root-prefix=/usr --enable-elf-shlibs --disable-uuidd --disable-fsck --disable-e2initrd-helper --disable-libblkid --disable-libuuid --disable-fuse2fs
```

Provided the configuration finished successfully, we can now build the code and install it.

```bash
make 
make install
```

It is possible to build rpm packages with `make rpm`, however this results in an error in root acls during in one fo the tests when an unpatched kernel is employed.
To build the rpm packages, one can rename test `d_print_acl` to `_d_print_acl` to disable it, the same for `m_rootdir_acl` renamed to `_m_rootdir_acl`.
(Or one could delete it too.)

Thus, to build the rpms, one can run the following:

```bash
cd ~/e2fsprogs/tests
mv d_print_acl _d_print_acl
mv m_rootdir_acl _m_rootdir_acl
cd ~/e2fsprogs
make rpm
```

*Note:*
*Disabling tests is typically not a  good way to go, however here it is the only easy way of building the rpm.*
*A longterm solution would be to understand the test failure and fix the underlying cause.*

### A note on RPMs and Lustre RPMs

It is not necessary to build and install the rpm-version of e2fsprogs for a binary installation of lustre.
However the rpm become necessary when one attempts to build the lustre rpms, as the code will check for the available version of e2fsprogs.
Thus, to build a lustre rpm, it is necessary to install the e2fsprogs rpms which by default will be built into `~/rpmbuild/RPMS/x86_64`.

```bash
cd ~/rpmbuild/RPMS/x86_64
dnf install ./*.rpm
```

## Lustre & the Patched Kernel - Build and Install

### Pre-Prepare Lustre

While we downloaded lustre and selected the version, we did not yet create the configuration scripts.
Files are copied to and from the lustre source code, thus we should prepare it before building the patched kernel, necessary for building lustre.
The configuration scripts for the lustre source code are prepared using `autogen.sh`

```bash
cd ~/lustre-release
sh ./autogen.sh
```

### Prepare Patched Kernel

Before the lustre server can be built and installed, is is necessary to prepare a patched kernel and install it first.

If the current kernel is supported by lustre, the easy solution is to download lustre using dnf, using `dnf download --source kernel`.
However, as of updating this present guide (2025/05/09), lustre 2.16.1 supports kernel-5.14.0-427.33.1.el9_4 and no later.
Thus is is necessary to match the kernel source code that we target for the patched kernel we intend to build.
For this, wee employ the kernel-5.14.0-427.33.1.el9_4.src.rpm we downloaded previously from the Rocky vault.

We can prepare the directory structure for rpmbuild (it may even do this automatically):

```bash
mkdir -p ~/kernel/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd ~/kernel && echo '%_topdir %(echo $HOME)/kernel/rpmbuild' > ~/.rpmmacros
```

This allows us to install the kernel sources from the local src.rpm.
The version employed here is kernel-5.14.0-427.33.1.el9_4 from the Rocky vault, as later builds are not currently supported by lustre (as of 2.16.1).

Install the kernel into the build tree:

```bash
cd ~/kernel
rpm -ivh ~/kernel-5.14.0-427.33.1.el9_4.src.rpm 
```

Next, following the tutorial, we prepare the kernel:

```bash
cd ~/kernel/rpmbuild && rpmbuild -bp --target=`uname -m` ./SPECS/kernel.spec
```

*Note*
Let us build against a fixed lustre server version, 2.16.1 is up to date as of writing this:

To build the patches specific to the kernel, we now copy the kernel configuration file into the lustre source code repository, overwriting any potentially existing files.

```bash
cp \
~/kernel/rpmbuild/BUILD/kernel-5.14.0-427.33.1.el9_4/linux-5.14.0-427.33.1.el9.`uname -m`/configs/kernel-5.14.0-`uname -m`.config \
~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config
```

Then we need to add two lines to the kernel config file in the lustre repository for the IO Scheduler, required for lustre:

CONFIG_IOSCHED_DEADLINE=y
CONFIG_DEFAULT_IOSCHED="deadline"

Which can be achieved via the proposed command line as follows:

```bash
sed -i '/# IO Schedulers/a CONFIG_IOSCHED_DEADLINE=y\nCONFIG_DEFAULT_IOSCHED="deadline"' ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config
```

The lustre source code provides a series of patches that become more extensive as the kernel develops.
These can be, as per the tutorial, collected into a single file.
The tutorial limited the kernel range to rhel8.7-series, which was adapted to include rhel9.4-series for rocky 9.4 support.

Thus the line becomes the following:

```bash
cd ~/lustre-release/lustre/kernel_patches/series && \
for patch in $(<"5.14-rhel9.4.series"); do \
     patch_file="$HOME/lustre-release/lustre/kernel_patches/patches/${patch}"; \
     cat "${patch_file}" >> "$HOME/lustre-kernel-`uname -m`-lustre.patch"; \
done
```

The collated patch can then be copied from the lustre source directory into the rpm build tree giving us the prepared configuration for the patched kernel:

```bash
cp ~/lustre-kernel-`uname -m`-lustre.patch ~/kernel/rpmbuild/SOURCES/patch-5.14.0-lustre.patch
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
cat ~/lustre-release/lustre/kernel_patches/kernel_configs/kernel-5.14.0-5.14-rhel9.4-`uname -m`.config >> ~/kernel/rpmbuild/SOURCES/kernel-`uname -m`.config
```

### Build Patched Kernel

And now we can finally start to build the kernel:

```bash
cd ~/kernel/rpmbuild && buildid="_lustre" && \
rpmbuild -ba --with firmware --target `uname -m` --with baseonly \
           --without kabichk --define "buildid ${buildid}" \
           ~/kernel/rpmbuild/SPECS/kernel.spec
```

### Install Patched Kernel

Once successfully built, we can then install the new kernel and reboot the system.

```bash
cd ~/kernel/rpmbuild/RPMS/`uname -m`/
rpm -Uvh --replacepkgs --force kernel-*.rpm
reboot
```

After the reboot it is possible to verify that the newly installed kernel has been loaded by running the following command:

```bash
uname -r
```

#### Note

Many of the commands add content to files.
As a result it is not advised to rerun commands.
IF at any step during the process steps fails, analyze the failure and return to the original source rpm package and retrace the steps.

### Prepare and Build lustre

As the underlying operating system is now prepared, the lustre server can now be built and installed.
We configure lustre while pointing it at the kernel source code that was employed to build the patched kernel.
An important caveat is that as a local test VM, the kernel was built as root under /root, not necessarily a recommended approach.

```bash
cd ~/lustre-release
./configure --with-linux=/root/kernel/rpmbuild/BUILD/kernel-5.14.0-427.33.1.el9_4/linux-5.14.0-427.33.1_lustre.el9.`uname -m`/ --disable-gss --disable-shared --disable-crypto
```

Now the lustre server can be built and installed:

```bash
make
make install
depmod -a
```

#### Building Lustre RPMs

To build the lustre rpm packages, it is "only" necessary to call "make rpms", with one important different in the configuration.
Shared libraries are required to build the rpm packages, thus the configure line becomes the following:

```bash
cd ~/lustre-release
./configure --with-linux=/root/kernel/rpmbuild/BUILD/kernel-5.14.0-427.33.1.el9_4/linux-5.14.0-427.33.1_lustre.el9.`uname -m`/ --disable-gss --disable-crypto
```

Otherwise, building the rpms will fail at lustre-devel.

### Run and Test Lustre Locally

*Note:*
*A Rocky 9.4 quirk is that the test script will not work by default.*
*This possibly loops back to some checks in the script and running it will lead to an error...*
*It turns out, this error is related to the hostname.*

*Not ideal, but for a local vm it works, set the hostname to `localhost`:*

```bash
hostnamectl set-hostname localhost
```

Then continue as usual, we launch a test instance via the tutorial recommended script :

```bash
/usr/lib64/lustre/tests/llmount.sh
```

When successful, the should be similar to this:

```bash
mgs: Rocky Linux release 9.4 (Blue Onyx)
MGS_OS_VERSION_ID=9.4
MGS_OS_ID=rocky
MGS_OS_VERSION_CODE=151257088
MGS_OS_ID_LIKE=rhel centos fedora rocky
mds1: Rocky Linux release 9.4 (Blue Onyx)
MDS1_OS_ID=rocky
MDS1_OS_VERSION_CODE=151257088
MDS1_OS_ID_LIKE=rhel centos fedora rocky
MDS1_OS_VERSION_ID=9.4
ost1: Rocky Linux release 9.4 (Blue Onyx)
OST1_OS_VERSION_ID=9.4
OST1_OS_VERSION_CODE=151257088
OST1_OS_ID=rocky
OST1_OS_ID_LIKE=rhel centos fedora rocky
client: Rocky Linux release 9.4 (Blue Onyx)
CLIENT_OS_VERSION_ID=9.4
CLIENT_OS_ID_LIKE=rhel centos fedora rocky
CLIENT_OS_ID=rocky
CLIENT_OS_VERSION_CODE=151257088
Stopping clients: localhost /mnt/lustre (opts:-f)
Stopping clients: localhost /mnt/lustre2 (opts:-f)
localhost: executing set_hostid
Loading modules from /usr/lib64/lustre/tests/..
detected 6 online CPUs by sysfs
libcfs will create CPU partition based on online CPUs
ptlrpc/ptlrpc options: 'lbug_on_grant_miscount=1'
gss/krb5 is not supported
quota/lquota options: 'hash_lqs_cur_bits=3'
Formatting mgs, mds, osts
Format mds1: /tmp/lustre-mdt1
Format ost1: /tmp/lustre-ost1
Format ost2: /tmp/lustre-ost2
Checking servers environments
Checking clients localhost environments
Loading modules from /usr/lib64/lustre/tests/..
detected 6 online CPUs by sysfs
libcfs will create CPU partition based on online CPUs
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
Starting client: localhost:  -o user_xattr,flock 192.168.122.221@tcp:/lustre /mnt/lustre
Using TIMEOUT=20
osc.lustre-OST0000-osc-ffff97a4dcc0a800.idle_timeout=debug
osc.lustre-OST0001-osc-ffff97a4dcc0a800.idle_timeout=debug
setting jobstats to procname_uid
Setting lustre.sys.jobid_var from disable to procname_uid
Waiting 90s for 'procname_uid'
disable quota as required
```
