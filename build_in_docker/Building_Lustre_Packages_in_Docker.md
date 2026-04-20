# Building Lustre Packages in Docker

Docker is a container environment that allows some isolation between processes run on the host and the container.
In the context of lustre under linux, it provides a lightweight foundation on which the packages can be built for other distributions without the effort of setting up a virtual machine.

The motivation here is to provide a simple to use abstraction layer that allows building packages, not to provide security or isolation.
Thus the assumption made is, that the objective is to build packages for your own use - not offer any kind of secure or secured service.

## Preparing Docker

Step one consists of installing docker.
On openSUSE, the approach is to run `zypper install -y docker` which would install the required packages.
The process with differ slightly depending on distribution.

Installing docker should create a docker user group.
By default, access to docker is limited to root and members of the docker group.
For simplicity, it may thus be useful to add the build-user (which may be your own account or a service account) to the docker user group.

After installation it may be necessary to manually start and/or enable the docker service.
When changing the daemon.json file, you may need to restart the docker service.

This can be achieved using the systemctl utility:

```bash
systemctl enable docker.service
systemctl start docker.service
systemctl restart docker.service
```

The status can also be checked using the following:

```bash
systemctl status docker.service
```

And if you need to disable it;

```bash
systemctl stop docker.service
systemctl disable docker.service
```

Detailed instructions are also available on the docker website: [https://docs.docker.com/desktop/setup/install/linux/](https://docs.docker.com/desktop/setup/install/linux/)

### Docker Settings

In the context of building lustre, two docker settings are of relevance, network and storage:

- Which network does docker use?
It is possible for the docker network to use an internal IP range which can cause issues with network connectivity on the machine.
If this is the case, you need to set your own IP range.
- Is there enough space?
Building docker in Lustre cna lead to large images and space requirements.
By default docker uses `/var/lib\docker` (on openSUSE) which may be space constrained on the system partition.
My personal choice was to create a `/home/docker` directory for docker which sits on the home partition and can thus be more easily cleared out if or when required.

These settings are set in `/etc/docker/daemon.json` by adding the options  below.

```text
cat daemon.json
{
  "data-root": "/home/docker",
  "default-address-pools":
  [
    {"base":"10.10.0.0/16","size":24}
  ]
}
```

More information is available in the docker docs: [https://docs.docker.com/engine/daemon/](https://docs.docker.com/engine/daemon/)

At this point you should have a working docker installation.
A simple way of testing this may be to just launch a minimal container using a docker example:

First `pull` an image:

```bash
docker pull hello-world:linux
```

Then run an image:

```bash
docker pull hello-world:linux
```

It is noteworthy that internally, docker runs as root.
Thus any files written by docker will be owned by root.

## Running a Build

### Rocky 9.x

It is planned or hoped that the scripts can be upstreamed into the lustre code.
For now, they are available in a personal public github repository at [https://github.com/DetlevCM/lustre-build-instructions/tree/main](https://github.com/DetlevCM/lustre-build-instructions/tree/main).

The current structure requires a directory called `build` which needs to contain the build script. Ideally, the directory also contains a copy of the lustre source code and, for the server, the patched e2fsprogs source code, however if not, they will be downloaded using `git clone`.
As the source repositories will be copied at compile, it is possible to mount these via the docker `--volume` option.
By default, the script and container will build for the current version of the kernel using the master branch of lustre.
However it is possible to define a linux kernel from the Rocky Vault as well as a specific lustre version, as well as e2fsprogs versions.

Building the base container is achieved with the following command:

```bash
docker build . -f lustre_builder_for_rocky -t lustre_builder_for_rocky
```

Assuming you have the build-directory with the build script, the simplest execution would be the following:

```bash
docker run  --volume ./build:/build  lustre_builder_for_rocky
```

An option to provide an external copy of the lustre source code would be the following execution, otherwise a git clone will be executed.

```bash
docker run  --volume ./build:/build --volume ./lustre-release:/build/lustre-release.src lustre_builder_for_rocky
```

If additional options are to be passed to the container, this can be achieved by placing them as a string in a variable called `BuilderOptions` as follows:

```bash
docker run  --volume ./build:/build  -e BuilderOptions="--versionLustre=2.17.0 --versionLinux=5.14.0-570.32.1.el9_6.x86_64" lustre_builder_for_rocky
```

The server is built by adding the keyword server to the build options:

```bash
docker run  --volume ./build:/build  -e BuilderOptions="server" lustre_builder_for_rocky
```

Available options are the following:

```bash
server
--versionE2fsck=
--versionLustre=
--versionLinux=
```

This will create a directory of the pattern `lustre-lustreVersion-linuxVersion-rpm` with the regular kernel modules as well as the dkms modules in the build directory.
These directories can then be copied and used to install or distribute the custom built lustre rpms.

### OpenSUSE Leap 15.6

OpenSUSE Leap is only supported for Lustre Client builds.
A further restriction is that the container can only build against the latest kernel in the repository or requires the user to provide the relevant kernel rpms.
When the latest kernel is employed during the build, the container will provide the rpms in a separate directory under `build/`, so that it is possible to install the employed kernel on the target clients.

Similar to Rocky (previous section) the container can be built using docker as follows:

```bash
docker build . -f lustre_builder_for_opensuse_leap -t lustre_builder_for_opensuse_leap
```

The options follow the pattern used for Rocky.
Assuming you have the build-directory with the build script, the simplest execution would be the following:

```bash
docker run  --volume ./build:/build  lustre_builder_for_rocky
```

An option to provide an external copy of the lustre source code would be the following execution, otherwise a git clone will be executed.

```bash
docker run  --volume ./build:/build --volume ./lustre-release:/build/lustre-release.src lustre_builder_for_rocky
```

If additional options are to be passed to the container, this can be achieved by placing them as a string in a variable called `BuilderOptions` as follows.
The `--versionLinux` flag in this case provides the numerical kernel version, such as `6.4.0-150600.23.92` and requires a directory `/build/linux-$versionLinux` that contains the following rpms:

- `kernel-default*.rpm`
- `kernel-syms*.rpm`
- `kernel-macros.rpm`
- `kernel-devel*.rpm`

It should be noted that that the script does not check the version numbers of the rpms, however using different versions will lead to failures as the lustre code will most likely not find the relevant dependencies.

```bash
docker run  --volume ./build:/build  -e BuilderOptions="--versionLustre=2.17.0 --versionLinux=6.4.0-150600.23.92" lustre_builder_for_rocky
```
