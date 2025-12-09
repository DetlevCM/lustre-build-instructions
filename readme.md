# About these Texts

The Lustre file system is an open parallel file system used in high performance computing.
Lustre can be installed from readily available `.rpm` files for specific distributions or alternatively built from source.

In order to test and experiment (or develop), it is advisable to set up a test system.
The current developers of lustre (Whamcloud, written October 2024) provide a set of instructions for the compilation of the lustre software on older releases, however more recent distros are lacking.
(Though the `.rpm` files are available for other distributions.)

The foundations for the instructions presented herein is a tutorial for building a test-lustre on Rocky 8.7 as provided by Whamcloud, available here: [https://wiki.whamcloud.com/pages/viewpage.action?pageId=258179277](https://wiki.whamcloud.com/pages/viewpage.action?pageId=258179277)

This tutorial has been adapted to build lustre on other releases, resolving missing dependencies as well as the odd quirk.

The work was carried out at the Humboldt Universität zu Berlin at the Computer- und Medienservice.

**Please note that in this adapted configuration, shortcuts have been taken and there is no guarantee of all features working.**
**It builds and it installs, it seems to work, that is it.**
**The result obtained from these tutorials is intended as a local sandbox only.**

- [Building Lustre Server on Rocky 8.10](lustre_server_rocky8.10.md)
- [Building Lustre Server on Rocky 9.4](lustre_server_rocky9.4.md)
- [Building a Patchless Lustre Server on Rocky 9.4/9.6](lustre_server_rocky9.x_patchless.md)
