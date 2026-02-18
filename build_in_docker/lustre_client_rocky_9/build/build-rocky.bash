#/bin/bash


##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##
LustreSourceRepo=/build/lustre-release.bak
Version="2.17.0"
LinuxVersion=""
## set kernel-devel manually
#linuxVersion="5.14.0-611.27.1.el9_7.x86_64"
linuxVersion=5.14.0-570.22.1.el9_6.x86_64
#linuxVersion=5.14.0-503.23.2.el9_5.x86_64

## e2fsprogs repo only needed with server build
e2fsprogsSourceRepo=/build/e2fsprogs.bak
noarchVersion=""


## if a Linux version is set, we also need to be able to define noarch
if [ -n $linuxVersion ];
then
## written for modern bash
noarchVersion=${Linux::-6}noarch
fi

## Optional:
## in debug mode, run the script with an additional keyword "server"
## build-rocky.bash server
## this will also build a patchless server rpm
## at the moment this only works for the "current kernel" in the container
## picking a specific linux target currently causes issues

##
## Now start the scripted process
##

cd /build


## check if lustre repo exists, if not clone it
## https://stackoverflow.com/questions/651038/how-do-i-clone-a-git-repository-into-a-specific-folder
if [ ! -d "$LustreSourceRepo" ];
then
git clone "https://review.whamcloud.com/fs/lustre-release" $LustreSourceRepo
fi
## if the user wanted the server rpms, we need some extra steps:
if [ "$1" == "server" ];
then
if [ ! -d "$e2fsprogsSourceRepo" ];
then
git clone "https://review.whamcloud.com/tools/e2fsprogs"
fi
fi

## if the user set a custom Linux version, use that
## https://unix.stackexchange.com/questions/571037/check-for-non-empty-string-in-the-shell-instead-of-z
if [[ -n $linuxVersion ]];
then

## only works for Rocky 9.x
RockyVersionStep=$(echo $linuxVersion | cut -d '.' -f 6)
RockyVersion=9.$(echo $RockyVersionStep | cut -d '_' -f 2)

## check if the file aready exists, only download if not
if [ ! -f /build/kernel-devel-$linuxVersion.rpm ];
then
cd build
#http://d.rockylinux.org/vault/rocky/9.0/devel/x86_64/os/Packages/k/kernel-devel-5.14.0-70.30.1.el9_0.x86_64.rpm
wget http://d.rockylinux.org/vault/rocky/$RockyVersion/devel/x86_64/os/Packages/k/kernel-devel-$linuxVersion.rpm
fi

## install kernel-devel
dnf install -y ./kernel-devel-$linuxVersion.rpm

## update the kernel related packages for the lustre server
if [ "$1" == "server" ];
then
if [ ! -f /build/kernel-abi-stablelists-$noarchVersion.rpm ];
then
cd build
#https://dl.rockylinux.org/vault/rocky/9.4/devel/x86_64/os/Packages/k/kernel-abi-stablelists-5.14.0-427.16.1.el9_4.noarch.rpm
wget https://dl.rockylinux.org/vault/rocky/$RockyVersion/devel/x86_64/os/Packages/k/kernel-abi-stablelists-$noarchVersion.rpm
fi
if [ ! -f /build/kernel-rpm-macros-$linuxVersion.rpm ];
then
cd build
wget http://d.rockylinux.org/vault/rocky/$RockyVersion/devel/x86_64/os/Packages/k/kernel-rpm-macros-$linuxVersion.rpm
fi
if [ ! -f /build/kernel-debuginfo-$linuxVersion.rpm ];
then
cd build
wget http://d.rockylinux.org/vault/rocky/$RockyVersion/BaseOS/x86_64/debug/tree/Packages/k/kernel-debuginfo-$linuxVersion.rpm
fi

dnf install -y ./kernel-abi-stablelists-$linuxVersion.rpm ./kernel-rpm-macros-$linuxVersion.rpm ./kernel-debuginfo-$linuxVersion.rpm
fi

else
## else get an set the version from the container
Linux=$(ls /usr/src/kernels/) # get devel version from container
fi


## build and install e2fsprogs if we want to build the server
if [ "$1" == "server" ];
then

Buildpath=/build/e2fsprogs-$Version-$linuxVersion
echo $Buildpath
cp -r $e2fsprogsSourceRepo /build/e2fsprogs-$Version-$linuxVersion
cd $Buildpath

## build e2fsprogs
git checkout v1.47.3-wc1 # tested
./configure --enable-elf-shlibs

## these two tests fail
cd $Buildpath/tests
mv d_print_acl _d_print_acl
mv m_rootdir_acl _m_rootdir_acl
cd $Buildpath

make rpm

## now install them, we're lazy, install all:
dnf install -y /root/rpmbuild/RPMS/x86_64/*.rpm
mkdir -p $Buildpath-rpm/
mv /root/rpmbuild/RPMS/x86_64/*.rpm $Buildpath-rpm/
fi



Buildpath=/build/lustre-release-$Version-$linuxVersion
echo $Buildpath
cp -r $LustreSourceRepo /build/lustre-release-$Version-$linuxVersion
cd $Buildpath

git checkout $Version

## disable the kernel check - we build in a container
sed -i 's/BuildRequires: kernel >= 3.10/#BuildRequires: kernel >= 3.10/g' $Buildpath/lustre.spec.in

./autogen.sh
if [ "$1" == "server" ];
then
./configure --enable-server --with-linux=/usr/src/kernels/$linuxVersion
else
./configure --with-linux=/usr/src/kernels/$linuxVersion
fi
make rpms

# make the folder read- and writable to all
chmod -R a+rw $Buildpath

mkdir -p $Buildpath-rpm
mv ./*.rpm $Buildpath-rpm/

