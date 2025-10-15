# Patchless Rocky 9 - Starting from 9.4, Upgrade to 9.6, Installation on 9.6

## Prepare The OS

Building Lustre in "patchless mode" avoids the need to build a patched kernel, which results in much fewer dependencies and a more robust build process, requiring only patched ext4 drivers for ldiskfs.

The following are the steps to build patchless lustre with success on Rocky 9.4, as well as Rocky 9.6.
(Tested with 5.14.0-570.49.1.el9_6.x86_64.)
It is important that any development packages are the same version as the kernel as lustre will be built for the installed version of the development package.
Options are thus to either update the entire system before building, or to fix the kernel related packages at a specific release.
(Specific versions can be obtained from the Rocky Vault as required. )

The base installation that was tested is a standard headless server install of Rocky with no other options selected.

### dnf install \<packages\> - The Foundations

Additional packages beyond the base os are required to build the software, any auto-resolved dependencies of the packages listed here should also be installed.

The lustre client does not require e2fsprogs, while the server does so.

```bash
dnf update -y

## for the kernel packages
yum -y groupinstall "Development Tools"
dnf config-manager --set-enabled crb

## essentials for building lustre
dnf install -y git gcc autoconf make libtool flex bison python3-devel glibc-static gcc-plugin-devel python3-sphinx python3-sphinx_rtd_theme
dnf install -y libmount-devel libnl3 libnl3-devel libyaml libyaml-devel

## to build rpms
dnf install -y kernel-abi-stablelists kernel-rpm-macros

## for e2fsprogs and lustre server
dnf install -y epel-release
dnf install -y libuuid-devel lsb_release texinfo libaio-devel swig quilt

## we need the ext4 sources for the server (not needed for the client)
dnf config-manager --set-enabled devel-debuginfo
dnf install -y kernel-debuginfo kernel-devel

## for GSS keyring backend requires
dnf install -y keyutils keyutils-libs keyutils-libs-devel

## for resource agents
dnf  config-manager --set-enabled resilientstorage
dnf install -y resource-agents
```

## Source Codes

```bash
## get the sources
cd
git clone "https://review.whamcloud.com/tools/e2fsprogs"
git clone "https://review.whamcloud.com/fs/lustre-release"
```

## Build e2fsprogs

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
cd ~/rpmbuild/RPMS/x86_64/
dnf install ./e2fsprogs-1.47.3-wc1.el9.x86_64.rpm \
./e2fsprogs-libs-1.47.3-wc1.el9.x86_64.rpm \
./e2fsprogs-devel-1.47.3-wc1.el9.x86_64.rpm \
./libss-1.47.3-wc1.el9.x86_64.rpm \
./libcom_err-1.47.3-wc1.el9.x86_64.rpm \
./libcom_err-devel-1.47.3-wc1.el9.x86_64.rpm
```

```bash
## build lustre
./autogen.sh
./configure --enable-server
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
