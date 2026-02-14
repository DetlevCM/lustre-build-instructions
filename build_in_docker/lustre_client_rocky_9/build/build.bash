#/bin/bash


##
## set whether lustre sources are already provided
## set the version og the lustre client to build
## set a specific linux kernel package to use if required
##
LustreSourceRepo=/build/lustre-release.bak
Version="2.17.0"
Linux=""
## set kernel-devel manually
#Linux="5.14.0-611.27.1.el9_7.x86_64"
#Linux=5.14.0-570.22.1.el9_6.x86_64
#Linux=5.14.0-503.23.2.el9_5.x86_64

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



## if the user set a custom Linux version, use that
## https://unix.stackexchange.com/questions/571037/check-for-non-empty-string-in-the-shell-instead-of-z
if [[ -n $Linux ]];
then

## only works for Rocky 9.x
RockyVersionStep=$(echo $Linux | cut -d '.' -f 6)
RockyVersion=9.$(echo $RockyVersionStep | cut -d '_' -f 2)

## check if the file aready exists, only download if not
if [ ! -f /build/kernel-devel-$Linux.rpm ];
then
#http://d.rockylinux.org/vault/rocky/9.0/devel/x86_64/os/Packages/k/kernel-devel-5.14.0-70.30.1.el9_0.x86_64.rpm
wget http://d.rockylinux.org/vault/rocky/$RockyVersion/devel/x86_64/os/Packages/k/kernel-devel-$Linux.rpm
fi

## install kernel-devel
dnf install -y ./kernel-devel-$Linux.rpm
else
## else get an set the version from the container
Linux=$(ls /usr/src/kernels/) # get devel version from container
fi





Buildpath=/build/lustre-release-$Version-$Linux
cp -r $LustreSourceRepo /build/lustre-release-$Version-$Linux
cd $Buildpath

git checkout $Version

# disable the kernel check - we build in a container
sed -i 's/BuildRequires: kernel >= 3.10/#BuildRequires: kernel >= 3.10/g' $Buildpath/lustre.spec.in

./autogen.sh
## currently I can oncly build the client in a container
#./configure --enable-server --with-linux=/usr/src/kernels/$Linux
./configure --with-linux=/usr/src/kernels/$Linux

make rpms

# make the folder read- and writable to all
chmod -R a+rw $Buildpath

mkdir -p $Buildpath-rpm
mv ./*.rpm mkdir cd $Buildpath-rpm/
