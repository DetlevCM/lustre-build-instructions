# Patchless Rocky 10.0 - UNSUPPORTED - EXPERIMENTAL

## Prepare The OS

Building Lustre in "patchless mode" avoids the need to build a patched kernel, which results in much fewer dependencies and a more robust build process, requiring only patched ext4 drivers for ldiskfs.

The following are the steps to build patchless lustre with success on Rocky 10.0. (Tested successfully on 6.12.0-55.12.1.el10_0.x86_64.)
It is important that any development packages are the same version as the kernel as lustre will be built for the installed version of the development package.
Options are thus to either update the entire system before building, or to fix the kernel related packages at a specific release.
(Specific versions can be obtained from the Rocky Vault as required. )

The base installation that was tested is a standard headless server install of Rocky with no other options selected.

### dnf install \<packages\> -  The Foundations

Additional packages beyond the base os are required to build the software, any auto-resolved dependencies of the packages listed here should also be installed.

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
dnf install -y libuuid-devel lsb_release texinfo libaio-devel swig
#quilt ## fails to find package

## we need the ext4 sources for the server (not needed for the client)
dnf config-manager --set-enabled devel-debuginfo
dnf install -y kernel-debuginfo kernel-devel

## for GSS keyring backend requires
dnf install -y keyutils keyutils-libs keyutils-libs-devel

## for resource agents -> somehow fails to find pacakge
#dnf  config-manager --set-enabled highavailibility
#dnf install -y resource-agents
```

## Source Codes

```bash
## get the sources
cd
git clone "https://review.whamcloud.com/tools/e2fsprogs"
git clone "https://review.whamcloud.com/fs/lustre-release"
```


At this point, we can successfully build the lustre client rpms.

For the lustre server client, it is necessary that we adjust one of the patches as of version 2.16.58_104_g6c4537f (15th Oct 2025), basically advancing the line number for the patch by 5 positions in `./lustre-release/ldiskfs/kernel_patches/patches/linux-6.10/ext4-delayed-iput.patch`, based on the result of `./lustre-release/ldiskfs/linux-stage/fs/ext4/super.c.rej`.
This will surely be adjusted properly in future lustre developments.

From:

```patch
@@ -1296,10 +1296,11 @@ static void ext4_put_super(struct super_block *sb)
 			 &sb->s_uuid);
 
 	ext4_unregister_li_request(sb);
+	flush_workqueue(sbi->s_misc_wq);
 	ext4_quotas_off(sb, EXT4_MAXQUOTAS);
 
 	flush_work(&sbi->s_sb_upd_work);
-	destroy_workqueue(sbi->rsv_conversion_wq);
+	destroy_workqueue(sbi->s_misc_wq);
 	ext4_release_orphan_info(sb);
 
 	if (sbi->s_journal) {
```

to:

```patch
@@ -1301,9 +1301,10 @@ static void ext4_put_super(struct super_block *sb)
 			 &sb->s_uuid);
 
 	ext4_unregister_li_request(sb);
+	flush_workqueue(sbi->s_misc_wq);
 	ext4_quotas_off(sb, EXT4_MAXQUOTAS);
 
-	destroy_workqueue(sbi->rsv_conversion_wq);
+	destroy_workqueue(sbi->s_misc_wq);
 	ext4_release_orphan_info(sb);
 
 	if (sbi->s_journal) {
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
dnf install ./e2fsprogs-1.47.3-wc1.el10.x86_64.rpm \
./e2fsprogs-libs-1.47.3-wc1.el10.x86_64.rpm \
./e2fsprogs-devel-1.47.3-wc1.el10.x86_64.rpm \
./libss-1.47.3-wc1.el10.x86_64.rpm \
./libcom_err-1.47.3-wc1.el10.x86_64.rpm \
./libcom_err-devel-1.47.3-wc1.el10.x86_64.rpm
```

```bash
## build lustre
./autogen.sh
./configure --enable-server
```

```bash
## Test installing the lustre rmps
dnf install \
./lustre-2.16.58_104_g6c4537f-1.el10.x86_64.rpm \
./kmod-lustre-2.16.58_104_g6c4537f-1.el10.x86_64.rpm \
./lustre-osd-ldiskfs-mount-2.16.58_104_g6c4537f-1.el10.x86_64.rpm \
./kmod-lustre-osd-ldiskfs-2.16.58_104_g6c4537f-1.el10.x86_64.rpm \
./lustre-osd-wbcfs-mount-2.16.58_104_g6c4537f-1.el10.x86_64.rpm \
./kmod-lustre-osd-wbcfs-2.16.58_104_g6c4537f-1.el10.x86_64.rpm
#./lustre-resource-agents-2.16.58_104_g6c4537f-1.el10.x86_64.rpm
```

For a local test, set the hostname :

```bash
hostnamectl set-hostname localhost
```

```bash
cd ~/lustre-release/lustre/tests/llmount.sh
```

This should successfully mount lustre under `/mnt/lustre`.
