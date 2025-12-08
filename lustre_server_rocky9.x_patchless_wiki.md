# Patchless Rocky 9 - Starting from 9.4, Upgrade to 9.6, Installation on 9.6

## Prepare The OS

Building Lustre in "patchless mode" avoids the need to build a patched kernel, which results in much fewer dependencies and a more robust build process, requiring only patched ext4 drivers for ldiskfs.

The following are the steps to build patchless lustre with success on Rocky 9.4, as well as Rocky 9.6.

The base installation that was tested is a standard headless server install of Rocky with no other options selected at installation time.

### Tested Combinations

While patchless lustre is easier to build, it nevertheless depends on a patched ext4 source code, which can change between kernel versions.
Typically a newer release of lustre should build on a (slightly) older kernel release.
However running a newer kernel will require a newer version of lustre, including potentially development releases (indicated by x.x.5x build numbers).

The versions, git tags for e2fsprogs and lustre, listed in the following table have been tested and found to build without issues, however no test suite was run:

|         kernel        |  e2fsprogs  | lustre  |
| --------------------- | ----------- | ------- |
| 5.14.0-427.33.1.el9_4 | v1.47.2-wc1 | 2.16.1  |
| 5.14.0-427.40.1.el9_4 | v1.47.3-wc1 | 2.16.1  |
| 5.14.0-570.52.1.el9_6 | v1.47.3-wc1 | 2.16.58 |
| 5.14.0-570.58.1.el9_6 | v1.47.3-wc1 | 2.16.59 |

It is possible to upgrade Rocky, for example from 9.6 and then downgrade the kernel and associated kernel packages to for example 9.4, to support the use of a release version of lustre instead of a development version.

### dnf install \<packages\> - The Foundations

Additional packages beyond the base os are required to build the software, any auto-resolved dependencies of the packages listed here should also be installed.
The lustre client does not require e2fsprogs, while the server does so.
It is assumed that Rocky has been installed on the system, only the headless server configuration is required, as per the introduction.

To prepare the server for the compilation of lustre, install the following required dependencies.
Some are optional, such as the GCC keyring backend and resource agents.

If you are building for an older kernel, you may need to download kernel-related packages from the Rocky Vault to ensure you have the correct version available, as the default in the repositories may have advanced to later releases.

It is important that any development packages are the same version as the kernel as lustre will be built for the installed version of the development package.
Options are thus to either update the entire system before building, or to fix the kernel related packages at a specific release.
Specific versions can be obtained from the Rocky Vault as required, for the following 9-series releases:

- https://dl.rockylinux.org/vault/rocky/9.4/BaseOS/x86_64/os/Packages/k/ for Rocky 9.4
- https://dl.rockylinux.org/vault/rocky/9.4/devel/x86_64/os/Packages/k/
- https://dl.rockylinux.org/vault/rocky/9.5/BaseOS/x86_64/os/Packages/k/ for Rocky 9.5
- https://dl.rockylinux.org/vault/rocky/9.5/devel/x86_64/os/Packages/k/
- https://dl.rockylinux.org/vault/rocky/9.6/BaseOS/x86_64/os/Packages/k/ for Rocky 9.6
- https://dl.rockylinux.org/vault/rocky/9.6/devel/x86_64/os/Packages/k/

If you build for a kernel from the Rocky Vault, you will need the following kernel related packages, from BaseOS for the first two, and devel from the second two:

- kernel-abi-stablelists
- kernel-rpm-macros
- kernel-debuginfo
- kernel-devel

Install the required packages as follows, replacing kernel packages with downloaded rpm packages from the Rocky Vault if applicable.

```bash
dnf update -y

## for the kernel packages
yum -y groupinstall "Development Tools"
dnf config-manager --set-enabled crb

## essentials for building lustre
dnf install -y git gcc autoconf make libtool flex bison python3-devel glibc-static gcc-plugin-devel python3-sphinx python3-sphinx_rtd_theme
dnf install -y libmount-devel libnl3 libnl3-devel libyaml libyaml-devel

## to build rpms - ensure same version as the kernel
dnf install -y kernel-abi-stablelists kernel-rpm-macros

## for e2fsprogs and lustre server
dnf install -y epel-release
dnf install -y libuuid-devel lsb_release texinfo libaio-devel swig quilt

## we need the ext4 sources for the server (not needed for the client)
## ensure same version as the kernel
dnf config-manager --set-enabled devel-debuginfo
dnf install -y kernel-debuginfo kernel-devel

## for GSS keyring backend requires
dnf install -y keyutils keyutils-libs keyutils-libs-devel

## for resource agents
dnf  config-manager --set-enabled resilientstorage
dnf install -y resource-agents
```

## Source Codes

You can obtain the source code directly from Whamcloud by cloning the git repositories using the following commands:

```bash
## get the sources
cd
git clone "https://review.whamcloud.com/tools/e2fsprogs"
git clone "https://review.whamcloud.com/fs/lustre-release"
```

## Build e2fsprogs

The first step to building lustre is to  build and install the patched e2fsprogs, including the development packages.
The following will check out a patched version of e2fsprogs and then build it with a minimum number of command line options.
It was observed that two tests fail, hence these need to be removed or moved to successfully build the rpm packages, which will also run the test suite.

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

After the rpms have been built, find the directory in which the rpms are built, then install at least the following to build lustre:

```bash
cd ~/rpmbuild/RPMS/x86_64/
dnf install ./e2fsprogs-1.47.3-wc1.el9.x86_64.rpm \
./e2fsprogs-libs-1.47.3-wc1.el9.x86_64.rpm \
./e2fsprogs-devel-1.47.3-wc1.el9.x86_64.rpm \
./libss-1.47.3-wc1.el9.x86_64.rpm \
./libcom_err-1.47.3-wc1.el9.x86_64.rpm \
./libcom_err-devel-1.47.3-wc1.el9.x86_64.rpm
```

Following the successful installation of e2fsprogs, it is possible to build lustre rpms from source.
Navigate to the directory check out the desired version (use `git tag` to list all tags.
Then generate the configuration files, configure and build.
The lustre client is built by default, the server has to be enabled via a command line flag.
Please see the generated configuration file for additional configuration flags, for example to build only the client (default) or to enable RDMA-networking support.

```bash
## build lustre
cd ~/lustre-release
## to build a stable release, checkout
#git checkout 2.16.1 # for Rocky 9.4
git checkout 2.16.58 # minimum version for Rocky 9.6, kernel 5.14.0-570.52.1.el9_6.x86_64
./autogen.sh
./configure --enable-server
make rpms
```

Next you can test lustre locally (if so desired) by installing the following rpms.
The names of the rpm files will depend on the selected lustre git tag.
Resource agents would only be required for a high availability setup.

```bash
## Test installing the lustre rmps
dnf install \
./lustre-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./kmod-lustre-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./lustre-osd-ldiskfs-mount-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
./kmod-lustre-osd-ldiskfs-2.16.58_104_g6c4537f-1.el9.x86_64.rpm \
# dnf install ./lustre-resource-agents-2.16.58_104_g6c4537f-1.el9.x86_64.rpm 
```

For a local test on Rocky Linux, it is necessary to set the hostname (assuming it is not already set):

```bash
hostnamectl set-hostname localhost
```

```bash
~/lustre-release/lustre/tests/llmount.sh
```

This should successfully mount lustre under `/mnt/lustre`.
