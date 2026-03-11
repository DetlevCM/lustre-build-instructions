#/bin/bash


##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##

#### NOTE: Client only
#### will use the latest kernel available in the container


LustreSourceRepo=/build/lustre-release.bak
Version="2.17.0"
linuxVersion=""
## set kernel-devel manually
#linuxVersion="linux-6.4.0-150600.23.87"


## fails to install via Dockerfile...
## so these need to be installed via the bash script
zypper install -y kernel-syms kernel-macros kernel-default kernel-default-devel

## get the current linux version in the container in a very hacky way...
linuxVersion=$(ls /usr/src/linux-* | cut -c 10- | head -1)
# remove trailing colon
linuxVersion=${linuxVersion::-1}

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

./configure --with-linux=/usr/src/$linuxVersion --with-linux-obj=/usr/src/$linuxVersion-obj/x86_64/default

make rpms

# make the folder read- and writable to all
chmod -R a+rw $Buildpath

mkdir -p $Buildpath-rpm
mv ./*.rpm $Buildpath-rpm/

