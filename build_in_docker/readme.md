# Building Lustre rpms in Docker - Client Only

A docker container to build the lustre client for Rocky 9.x against different kernels, as well as lustre server.
For Rocky 9.x, it is possible to select different kernels from the RockyVault.

On OpenSUSE Leap 15.6 and 16.0 the client can be built within a container.
The latest kernel in the container is employed by default, it is possible to supply custom packages to build against a different kernel.

On Ubuntu 24.04, the client can be built within a container. Only the latest kernel in the container is currently supported.
