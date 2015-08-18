#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

MIRROR=http://centosmirror.go4hosting.in/centos/7/isos/x86_64
CUR_TIME=`date +%FT%TZ`
DVD_LAYOUT=./c7-min
DVD_TITLE='C7-xen'
ISO_DIR=./isos
CUSTOM_RPMS=./rpms
ISO_FILENAME=c7-xen.iso
MOUNT_POINT=/mnt
ISO=CentOS-7-x86_64-Minimal-1503-01.iso
ANACONDA_DIR=./XenInBox
XenCloudImages=./XenCloudImages
CentOS_7_VmImage=CentOS-7-x86_64-XenCloud.qcow2.xz
CentOS_7_VmImage_src=http://183.82.4.49/cloud_images/CentOS-7-x86_64-XenCloud.qcow2.xz
CentOS_6_VmImage=CentOS-6-x86_64-XenCloud.qcow2.xz
CentOS_6_VmImage_src=http://183.82.4.49/cloud_images/CentOS-6-x86_64-XenCloud.qcow2.xz


function fetch_iso() {
    if [ ! -d $ISO_DIR ]; then
        mkdir -p $ISO_DIR
    fi
    
    if [ ! -e $ISO_DIR/$ISO ]; then
        echo "No local copy of $ISO. Fetching latest $ISO"
        curl -o $ISO_DIR/$ISO $MIRROR/$ISO
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
    echo "Populating Layout"   
    rsync -avp $MOUNT_POINT/ $DVD_LAYOUT/
    umount $MOUNT_POINT
    echo "Copying xen dependency RPMS"
    rsync -avp $CUSTOM_RPMS/ $DVD_LAYOUT/Packages/
    
    echo "Finished Populating Layout"
}

function modify_boot_menu() {
    echo "Modifying grub boot menu"
    cp ./isolinux.cfg $DVD_LAYOUT/isolinux/
}

function add_VM_images() {
    if [ ! -d $XenCloudImages ]; then
        mkdir -p $XenCloudImages
    fi
    
   echo "Adding CentOS-7 VM image"
   if [ ! -e $XenCloudImages/$CentOS_7_VmImage ];then
       echo "$CentOS_7_VmImage doesn't exist downloading now"
       curl -o $XenCloudImages/$CentOS_7_VmImage $CentOS_7_VmImage_src
   fi
   cp $XenCloudImages/$CentOS_7_VmImage $DVD_LAYOUT
   cp ./CentOS-7-demoVm.cfg $DVD_LAYOUT
   echo "Added CentOS-7 VM image"
 
   echo "Adding CentOS-6 VM image"
   if [ ! -e $XenCloudImages/$CentOS_6_VmImage ];then
       echo "$CentOS_6_VmImage doesn't exist downloading now"
       curl -o $XenCloudImages/$CentOS_6_VmImage $CentOS_6_VmImage_src
   fi
   cp $XenCloudImages/$CentOS_6_VmImage $DVD_LAYOUT
   cp ./CentOS-6-demoVm.cfg $DVD_LAYOUT
   echo "Added CentOS-6 VM image"
}

function update_anaconda(){
     if [ ! -d $ANACONDA_DIR ]; then
          git clone -b c7 https://github.com/gautamMalu/XenInBox
     fi
     pushd $ANACONDA_DIR > /dev/null 2>&1
     git pull
     ./scripts/makeupdates -t c7-working
     popd > /dev/null 2>&1
     echo "Copying updates.img"
     cp $ANACONDA_DIR/updates.img $DVD_LAYOUT/
     
}

function cleanup_layout() {
    echo "Cleaning up $DVD_LAYOUT"
    find $DVD_LAYOUT -name TRANS.TBL -exec rm '{}' +
    COMPS_XML=`find $DVD_LAYOUT/repodata -name '*.xml' ! -name 'repomd.xml' -exec basename {} \;`
    mv $DVD_LAYOUT/repodata/$COMPS_XML $DVD_LAYOUT/repodata/comps.xml 
    find $DVD_LAYOUT/repodata -type f ! -name 'comps.xml' -exec rm '{}' +
}


function create_newiso() {
    add_VM_images
    modify_boot_menu
    update_anaconda
    cleanup_layout
    echo "Preparing NEW ISO"
    pushd $DVD_LAYOUT > /dev/null 2>&1

    discinfo=`head -1 .discinfo`
    createrepo -v -g repodata/comps.xml .
    echo "Creating NEW ISO"
    genisoimage -r -R -J -T -v \
     -no-emul-boot -boot-load-size 4 -boot-info-table \
     -V "$DVD_TITLE" -p "xen" \
     -A "$DVD_TITLE - $CUR_TIME" \
     -b isolinux/isolinux.bin -c isolinux/boot.cat \
     -x "lost+found" -o ../$ISO_DIR/$ISO_FILENAME .
    echo "Fixing up NEW ISO"
    popd > /dev/null 2>&1    

    echo implantisomd5 $ISO_FILENAME
    implantisomd5 $ISO_DIR/$ISO_FILENAME
    
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
    if [ $arg = 'fetch' ]; then
	fetch_iso
    fi

    if [ $arg = 'layout' ] ; then
        create_layout
    #    cleanup_layout
    fi
    
    if [ $arg = 'finish' ] ; then
        create_newiso
    fi
done
