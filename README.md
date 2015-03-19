# Centos 6.6 Xen iso Builder

This repo allows one to create a custom CentOS 6.6 which delivers Xen 4.4 stack for CentOS 6.6.
It has been forked from [https://github.com/joyent/mi-centos-7]

## Requirements

In order to use this repo, you need to have the following:

 * A running CentOS instance (physical or virtual) with spare disk space
 * I have used it with CentOS 6.6 final ,but it should work well with othere versions of CentOs also 

## Setup

Included is a `setup_env.sh` script to be run inside the CentOS instance.  This
script will install the necessary packages required to create a custom ISO.

## Using

The next script is `build_Xen_iso.sh` which takes a series of commands:

 * fetch
 * layout
 * finish

### fetch
This command will fetch the DVD ISO from a given URL, I am using the one which is fstest for me. If an iso is already there then it will recheck its checksum with latest iso. If they do not match it will download the lastest iso.

### layout
This command will extract the ISO and place it onto disk.

## finish
This command will copy over the kickstart file in `./ks.cfg`, modify the boot menu to add the kickstart file, and creates the ISO.

You can run each command separately or all together.

```
./build_Xen_iso.sh fetch
./build_Xen_iso.sh layout
./build_Xen_iso.sh finish
```

Or `./build_Xen_iso.sh fetch layout finish`.

The resulting ISO will be ready to boot and install a clean image ready for
with Xen working. 
Check it with by running xl info command.

## Default Settings For Image

* Stock Kernel
* US Keyboard and Language
* Firewall enabled with SSH allowed
* Passwords are using SHA512
* Firstboot disabled
* SELinux is set to disabled
* Timezone is set to UTC+5:30
* Default Packages installed


   * @core
   * base
