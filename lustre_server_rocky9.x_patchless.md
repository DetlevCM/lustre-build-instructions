# Patchless Rocky 9 - Starting from 9.4, upgrade to 9.6

## Prepare The OS

Lustre can be built in "patchless mode" which avoids the need to build a patched kernel.
This can provide a less fragile foundation for the lustre server code. 

The following are the steps to build patchless lustre with success on Rocky 9.4, followed by an updated Rocky 9.6. (Tested with 5.14.0-570.49.1.el9_6.x86_64.)
It is important that any development packages are the same version as the kernel as lustre will be built for the installed version of the development package.
Options are thus to either update the entire system before building, or to fix the kernel related packages at a specific release.

The base installation that was tested, is a standard headless server install of Rocky with no other options selected.

### dnf install <packages>

Additional packages are required to build the software with success. 
Any auto-resolved dependencies of the packages listed here should also be installed.

```bash
## for the kernel
yum -y groupinstall "Development Tools"
yum config-manager --set-enabled crb

## essentials
dnf install -y git gcc autoconf make libtool flex bison python3-devel glibc-static gcc-plugin-devel python3-sphinx python3-sphinx_rtd_theme

## for GSS keyring backend requires
dnf install -y keyutils keyutils-libs keyutils-libs-devel

## for lustre
dnf install -y libmount-devel libnl3 libnl3-devel libyaml libyaml-devel

## to build rpms
dnf install -y kernel-abi-stablelists  kernel-rpm-macros
```

At this point, we can successfully build the lustre client rpms.
The Lustre server requires patched e2fsprogs, which has further requirements.

```bash
## for e2fsprogs
dnf install -y libuuid-devel

dnf install -y epel-release
dnf install -y lsb_release texinfo

### carry on with the server
dnf install -y libaio-devel

## we need the ext4 sources for the server
dnf config-manager --set-enabled devel-debuginfo
dnf install -y kernel-debuginfo kernel-devel

## just to make configure happier
dnf install -y quilt swig
```

```bash
## get the sources
cd
git clone "https://review.whamcloud.com/tools/e2fsprogs"
git clone "https://review.whamcloud.com/fs/lustre-release"
```

## To build e2fsprogs


```bash
## build e2fsprogs
cd e2fsprogs
git checkout v1.47.3-wc1 # tested
./configure --enable-elf-shlibs

## these two tests fail
cd ~/e2fsprogs/tests
mv d_print_acl _d_print_acl
mv m_rootdir_acl _m_rootdir_acl
cd ~/e2fsprogs

make rpm
```

Find the directory in which the rpms are built, then install at least the following:

```bash
cd ~/cd rpmbuild/RPMS/x86_64/
dnf install ./e2fsprogs-1.47.3-wc1.el9.x86_64.rpm ./e2fsprogs-libs-1.47.3-wc1.el9.x86_64.rpm ./libcom_err-1.47.3-wc1.el9.x86_64.rpm ./libss-1.47.3-wc1.el9.x86_64.rpm ./libcom_err-devel-1.47.3-wc1.el9.x86_64.rpm ./e2fsprogs-devel-1.47.3-wc1.el9.x86_64.rpm
```

```bash
## build lustre
./autogen.sh
./configure --enable-server

## for resource agents
dnf  config-manager --set-enabled resilientstorage
dnf install resource-agents
```

```bash
## Test installing the lustre rmps

dnf install \
./lustre-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./kmod-lustre-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./lustre-osd-ldiskfs-mount-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./kmod-lustre-osd-ldiskfs-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./lustre-osd-wbcfs-mount-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./kmod-lustre-osd-wbcfs-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./lustre-iokit-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./lustre-resource-agents-2.16.58_104_g6c4537f-1.el9.x86_64.rpm
```

For a local test, set the hostname :

```bash
hostnamectl set-hostname localhost
```

```bash
cd ~/lustre-release/lustre/tests/llmount.sh
```

This should successfully mount lustre under `/mnt/lustre`.
