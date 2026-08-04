# Building Lustre rpms in Docker - Client Only

On Rocky the client and server can be built within a container.
By default the build will employ the latest kernel foe the current release.
For Rocky 9.x, it is possible to select different kernels from the RockyVault.
- 9.x
- 10.x

On OpenSUSE Leap the client can be built within a container.
The latest kernel in the container is employed by default, it is possible to supply custom packages to build against a different kernel.
- 15.6
- 16.0 


On Ubuntu the client can be built within a container. 
Only the latest kernel in the container is currently supported.
- 24.04 debian packages & dkms packages
- 25.04 debian packages, no dkms
- 26.04 debian packages, no dkms

On Debian the client can be built within a container. 
Only the latest kernel in the container is currently supported and needs to be manually set in the build file for now.
- 13 debian packages, no dkms
- 12 debian packages, no dkms
