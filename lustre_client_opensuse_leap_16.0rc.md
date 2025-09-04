# Building the Lustre Client on OpenSUSE Leap 16.0 Release Candidate - 2025/09/04

As part of some limited experimental local testing, the lustre client was built for OpenSUSE Leap 16.0, currently available as a release candidate.

The objective was to see if the lustre client could be built and seemed functional, with the aspiration to later test this with a live system.
Thus there is no information about the robustness and/or reliability of the current setup.
For this reason, these notes are very short, condensed and less structured, targeting the curious developer moreso than a future user.

The build employed used the following git hash of the lustre code: `5e403af18121c6f47e77049915928798207d16db` or short `5e403af181`.

## Setting up OpenSUSE Leap 16.0

The installation employed is very much a standard Leap installation wth the KDE Plasma desktop environment, which provides the majority of the required infrastructure.

To build lustre the following packages needed to be installed : 

```bash
zypper install -y git

zypper install -y kernel-develop kernel-syms

zypper install -y libtool python313-devel flex bison rpm-build swig keyutils-devel libmount-devel libnl3-devel libyaml-devel openssl-devel libdebuginfod-devel
```

## On to Building Lustre

Clone the lustre code:

```bash
git clone "https://review.whamcloud.com/fs/lustre-release"
```

At the time different branches of the lustre source code were tested.
Issues were encountered trying to build the lustre client with all but master-next, the development code for the future lustre 2.17.
This is possibly related to the use of kernel `6.12.0` in this distribution.

```bash
git checkout master-next
```

or

```bash
git checkout 5e403af181
```

Next we need to address some issues with the rpm build script:
In `lustre.spec.in` we add `%define sle_version 160000` as rpmbuild struggles to identify the OpenSUSE release version correctly.
We also remove `%if 0%{?suse_version} \ %debug_package \ %endif` which causes issues, with rpminfo complaining that debuginfo already exists.
Commenting out the latter does not seem to be sufficient.

Having thus prepared our build, we can configure it using the following line:

```bash
CFLAGS="-Wno-incompatible-pointer-types -Wno-implicit-function-declaration" ./configure --disable-server --enable-client
```

and then the standard

```bash
make
```

or

```bash
make rpms
```

to build the rpm packages.

These have then been installed.
From the very limited testing, the machine could then connect to a lustre file system and see/access files.
