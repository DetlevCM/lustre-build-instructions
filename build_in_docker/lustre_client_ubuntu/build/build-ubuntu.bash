#!/usr/bin/bash


##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##

#### NOTE: Client only
#### will use the kernel available in the container


LustreSourceRepo=/build/lustre-release.bak
Version="2.17.0"
linuxVersion=""

## Get the Linux Version from the headers
#linuxVersion="6.8.0-101"
linuxVersion="$(ls /usr/src/ | head -1 | cut -c 15-)"


## e2fsprogs repo only needed with server build
e2fsprogsSourceRepo=/build/e2fsprogs.bak
noarchVersion=""


## if a Linux version is set, we also need to be able to define noarch
if [ -n $linuxVersion ];
then
## written for modern bash
noarchVersion=${linuxVersion::-6}noarch
fi

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
zypper install -y /root/rpmbuild/RPMS/x86_64/*.rpm
mkdir -p $Buildpath-rpm/
mv /root/rpmbuild/RPMS/x86_64/*.rpm $Buildpath-rpm/
fi


Buildpath=/build/lustre-release-$Version-$linuxVersion
echo $Buildpath
cp -r $LustreSourceRepo /build/lustre-release-$Version-$linuxVersion
cd $Buildpath

git checkout $Version

./autogen.sh

## help for ubuntu:
## https://support.hpe.com/hpesc/public/docDisplay?docId=sd00001837en_us&page=GUID-08035157-261F-4107-B06A-2ABCE43B4BF4.html
./configure \
--with-linux=/usr/src/linux-headers-$linuxVersion \
--with-linux-obj=/usr/src/linux-headers-$linuxVersion-generic \
--with-linux-config=/boot/config-$linuxVersion-generic


# normal packages
make debs
mkdir -p $Buildpath-deb
mv $Buildpath/debs/*.deb $Buildpath-deb/

# dkms packages
make dkms-debs
mkdir -p $Buildpath-dkms-deb
mv $Buildpath/debs/*.deb $Buildpath-dkms-deb/


# make the folder read- and writable to all
chmod -R a+rw $Buildpath

mkdir -p $Buildpath-deb
mv $Buildpath/debs/*.deb $Buildpath-deb/

## the packages between with and without dkms seem identical, but there is a small
## size difference in the client utils -> just keep the two output directories for now
