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

## Running a Build

It is planned or hoped that the scripts can be upstreamed into the lustre code.
For now, they are available in a personal public github repot at [https://github.com/DetlevCM/lustre-build-instructions/tree/main](https://github.com/DetlevCM/lustre-build-instructions/tree/main).
