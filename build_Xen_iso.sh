#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

CUR_TIME=`date +%FT%TZ`
DVD_LAYOUT=/data/centos-6-xen-layout
DVD_TITLE='CentOS-6-xen'
ISO=CentOS-6.6-x86_64-netinstall.iso
ISO_DIR=/data/fetched-iso
ISO_FILENAME=./centos-6-xen.iso
KS_CFG=./ks.cfg
MIRROR=http://centosmirror.go4hosting.in/centos/6.6/isos/x86_64
MOUNT_POINT=/mnt/centos6

function fetch_iso() {
    if [ ! -d $ISO_DIR ]; then
        mkdir -p $ISO_DIR
    fi
    
    if [ ! -e $ISO_DIR/$ISO ]; then
        echo "No local copy of $ISO. Fetching latest $ISO"
        curl  -o $ISO_DIR/$ISO $MIRROR/$ISO
    fi
    
    echo "Checking to see if we have the latest $ISO:"
    echo "  Getting checksum"
    curl  -O $MIRROR/sha256sum.txt
    
    ISO_NAME=$(echo $ISO | cut -f1 -d'.')
    ISO_NAME=${ISO%.*}
    echo $ISO_NAME
    CHECKSUM=$(grep $ISO_NAME sha256sum.txt | cut -f1 -d' ')
    
    if [[ $(sha256sum $ISO_DIR/$ISO | cut -f1 -d' ') == "$CHECKSUM" ]]; then
        echo "  Checksums match, using local copy of $ISO"
    else
        echo "  Checksums do not match. Fetching latest $ISO"
        curl  -o $ISO_DIR/$ISO $MIRROR/$ISO
    fi
}

function create_layout() {
    echo "Creating ISO Layout"
    if [ -d $DVD_LAYOUT ]; then
        echo "Layout $DVD_LAYOUT exists...nuking"
        rm -rf $DVD_LAYOUT
    fi
    echo "Creating $DVD_LAYOUT"
    mkdir -p $DVD_LAYOUT

    # Check if $MOUNT_POINT is already mounted
    # This may happen if a previous build failed
    if [ $(grep $MOUNT_POINT /proc/mounts) ]; then
      echo "Unmounting $MOUNT_POINT from previous build..."
        umount $MOUNT_POINT
    fi

    echo "Mounting $ISO to $MOUNT_POINT"
    if [ ! -d $MOUNT_POINT ]; then
        echo "Creating $MOUNT_POINT..."
        mkdir $MOUNT_POINT
    fi
    mount $ISO_DIR/$ISO $MOUNT_POINT -o loop
    pushd $MOUNT_POINT > /dev/null 2>&1
    echo "Populating Layout"
    tar cf - . | tar xpf - -C $DVD_LAYOUT
    popd > /dev/null 2>&1
    umount $MOUNT_POINT
}

function copy_ks_cfg() {
    echo "Copying Kickstart file"
    cp $KS_CFG $DVD_LAYOUT/
}

function modify_boot_menu() {
    echo "Modifying grub boot menu"
    cp ./isolinux.cfg $DVD_LAYOUT/isolinux/
}

function create_newiso() {
#    cleanup_layout
    copy_ks_cfg
    modify_boot_menu
    echo "Preparing NEW ISO"
    pushd $DVD_LAYOUT > /dev/null 2>&1
    echo "Creating NEW ISO"
    mkisofs -r -R -J -T -v \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
     -V "$DVD_TITLE" -p "xen" \
     -A "$DVD_TITLE - $CUR_TIME" \
     -b isolinux/isolinux.bin -c isolinux/boot.cat \
     -x "lost+found" -o $ISO_FILENAME $DVD_LAYOUT
    echo "Fixing up NEW ISO"
    echo implantisomd5 $ISO_FILENAME
    implantisomd5 $ISO_FILENAME
    popd > /dev/null 2>&1
    echo "NEW ISO $ISO_FILENAME is ready"
}

# main line

usage()
{
    cat <<EOF
Usage:
        $0 [options] command [command]
option:
        -h                    - this usage

Commands:
        fetch                 - fetch ISO
        layout                - create layout for new ISO
        finish                - create the new ISO

EOF
    exit 1
}

args=`getopt -o h -n 'build_Xen_iso.sh' -- "$@"`

if [[ $# == 0 ]]; then
    usage;
fi

eval set -- $args

while true ; do
   case "$1" in
       -h)
            usage;
            break;;
       --)
           shift; break;;
   esac
done

for arg ; do
    if [ $arg = 'fetch' ] ; then
        fetch_iso
    fi
    if [ $arg = 'layout' ] ; then
        create_layout
    fi
    if [ $arg = 'finish' ] ; then
        create_newiso
    fi
done
