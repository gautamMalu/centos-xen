# Centos 7 Xen iso Builder

This repo allows one to create a custom CentOS 7 iso which delivers Xen 4.4 stack installed over CentOS 7 minmal install.


## Requirements

In order to use this repo, you need to have the following:

 * A running CentOS instance (physical or virtual) with spare disk space
 * I have used it with CentOS 6.6 final and Centos 7 ,but it should work well with othere versions of CentOs also 

## Setup

Included is a `setup_env.sh` script to be run inside the CentOS instance.  This
script will install the necessary packages required to create the custom ISO.

## Using

The next script is `build_Xen_iso.sh` which takes a series of commands:

 * fetch
 * layout
 * finish

### fetch
This command will fetch a CentOS 7 minimal ISO from a given mirror (see $MIRROR in build_xen_iso.sh), I am using the one which is fastest for me. If an iso is already there then it will recheck its checksum with latest iso. If they do not match it will download the lastest iso.

### layout
This command will extract the ISO and place it onto disk, and add required rpms to Packages.

## finish
This command will first fetch the custom anaconda from https://github.com/gautamMalu/XenInBox and make an updates.img file. After that it will copy that image, update the repodata and make the custom iso with name c7-xen.iso

c7-xen.iso will be in isos directory

You can run each command separately or all together.

```
sudo ./build_Xen_iso.sh fetch
sudo ./build_Xen_iso.sh layout
sudo ./build_Xen_iso.sh finish
```

Or

`sudo ./build_Xen_iso.sh fetch layout finish`

The resulting ISO will be ready to boot and install a clean image ready for
with Xen working. 
Check it with by running xl info command.

