#/bin/bash

## default variables for user parameters
versionKernelMacros=""
versionKernelSyms=""
versionKernel=""
BuildServer="false"
versionE2fsck="v1.47.3-wc1" # known good version for lustre 2.17.0
versionLustre="master"

versionLinux=""
noarchVersion=""

##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##
LustreSourceRepo=/build/lustre-release.src

## e2fsprogs repo only needed with server build
e2fsprogsSourceRepo=/build/e2fsprogs.src


function split_arguments() {
  echo "$1" | cut -d "=" -f 2
}

## process user arguments
for arg; do

echo $arg

if [ $arg == "server" ]  ; then
#BuildServer="true"
echo "unfortunately building the server is not currently supported on Leap by this script"
fi

if [[ $arg == --e2fsckVersion=* ]] ; then
  versionE2fsck=$(split_arguments $arg)
  echo $versionE2fsck
fi

if [[ $arg == --versionLustre=* ]] ; then
  versionLustre=$(split_arguments $arg)
  echo $versionLustre
fi

if [[ $arg == --versionLinux=* ]] ; then
  versionLinux="linux-"$(split_arguments $arg)
  echo $versionLinux
fi


done



##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##

#### NOTE: Client only
#### will use the latest kernel available in the container
#### or accepts user supplied rpms


## Current kernels can be found in the opensuse repositories, however there is no history:
## paths are included as a reference for potential future developments 
## there also seems to be version number mismatches in the repo - but not when insatlling via zypper
## https://download.opensuse.org/update/leap/15.6/sle/noarch/kernel-macros-6.4.0-150600.23.7.2.noarch.rpm
## https://download.opensuse.org/distribution/leap/15.6/repo/oss/x86_64/kernel-syms-6.4.0-150600.16.1.x86_64.rpm
## https://download.opensuse.org/distribution/leap/15.6/repo/oss/x86_64/kernel-default-6.4.0-150600.16.3.x86_64.rpm
## https://download.opensuse.org/distribution/leap/15.6/repo/oss/x86_64/kernel-default-devel-6.4.0-150600.16.3.x86_64.rpm
## https://download.opensuse.org/update/leap/15.6/sle/noarch/kernel-devel-6.4.0-150600.23.7.2.noarch.rpm


## if the versionLinux is blank:
if [ -z $versionLinux ] ; then

## install the latest packages needed to build lustre
zypper install -y kernel-syms kernel-macros kernel-default kernel-default-devel
## get the rpms for safekeeping, kernel-devel is really optional, but might just be good to keep
zypper install -y --force --download-only --no-recommends kernel-syms kernel-macros kernel-default kernel-default-devel kernel-devel

## get the current linux version in the container in a very hacky way...
versionLinux=$(ls /usr/src/linux-* | cut -c 10- | head -1)
# remove trailing colon
versionLinux=${versionLinux::-1}

#echo "FROM REPO"
## save the kernel packages so they are available
mkdir -p /build/$versionLinux
mv $(find /var/cache/zypp/packages/ -name 'kernel-default*') /build/$versionLinux
mv $(find /var/cache/zypp/packages/ -name 'kernel-syms*') /build/$versionLinux
mv $(find /var/cache/zypp/packages/ -name 'kernel-macros*') /build/$versionLinux
mv $(find /var/cache/zypp/packages/ -name 'kernel-devel*') /build/$versionLinux

elif [ -d /build/$versionLinux ] ; then
#echo "FROM DIR"
## move to the directory with the rpms and install them
## we only use the path of the directory - one directory per kernel release
## version number MUST match, as it is used later on for the lustre paths to object files, etc.
cd /build/$versionLinux
zypper install -y --force --no-recommends ./kernel-syms-*.rpm ./kernel-macros-*.rpm ./kernel-default-*.rpm ./kernel-default-devel-*.rpm
cd /build

else
## not the current kernel, no packages provided, so exit
echo "ERROR, current kernel undesired, required packages not supplied"
exit ; echo $1
fi

## e2fsprogs repo only needed with server build
e2fsprogsSourceRepo=/build/e2fsprogs.bak

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
git clone "https://review.whamcloud.com/tools/e2fsprogs" $e2fsprogsSourceRepo
fi
fi


## build and install e2fsprogs if we want to build the server
if [ "$BuildServer" == "true" ];
then

Buildpath=/build/e2fsprogs-$versionLustre-$versionLinux
echo $Buildpath
cp -r $e2fsprogsSourceRepo /build/e2fsprogs-$versionLustre-$versionLinux
cd $Buildpath

## build e2fsprogs
git checkout $versionE2fsck
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



Buildpath=/build/lustre-release-$versionLustre-$versionLinux
#echo $versionLinux
#echo $LustreSourceRepo
#echo $Buildpath
cp -r $LustreSourceRepo /build/lustre-release-$versionLustre-$versionLinux

cd $Buildpath
echo $(pwd)

git checkout $versionLustre

## disable the kernel check - we build in a container
sed -i 's/BuildRequires: kernel >= 3.10/#BuildRequires: kernel >= 3.10/g' $Buildpath/lustre.spec.in

./autogen.sh
#if [ "$BuildServer" == "true" ];
#then
## for the server support build we need to disable another check
#sed -i 's/! grep -q define\[\[\:space\:\]\]\*HAVE_SERVER_SUPPORT config.h 2> \/dev\/null/false/g'  $Buildpath/lustre.spec.in
#./configure --enable-server --with-linux=/usr/src/kernels/$versionLinux
#else
## currently supports only client builds
./configure --with-linux=/usr/src/$versionLinux --with-linux-obj=/usr/src/$versionLinux-obj/x86_64/default
#fi


## make regular rpms
make rpms
mkdir -p $Buildpath-rpm
mv ./*.rpm $Buildpath-rpm/

## make dkms rpms
make dkms-rpm
mkdir -p $Buildpath-dkms-rpm
mv ./*.rpm $Buildpath-dkms-rpm/

# make the folder read- and writable to all
chmod -R a+rw $Buildpath
chmod -R a+rw $Buildpath-rpm
chmod -R a+rw $Buildpath-dkms-rpm


