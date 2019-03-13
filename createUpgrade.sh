#!/bin/bash

# Mount a partition inside a .wic file (or any image file flashable with dd)
# Params:
#    1 - .wic file name (with path if needed)
#    2 - partition number [1-based] (leave blank to list partitions)
#    3 - mount point (full path to where the partition will be mounted)
#    4 - [optional] partition type (auto detected if not specified)
# To unmount: sudo umount /path/to/mount/point
mount_wic_partition() {
    local wic_file="$1"
    local partition_number="$2"
    local mount_point="$3"
    local partition_type="$4"
    local partition_info start_sector=0 sector_count=0

    [ -z "${wic_file}" ] && {
        echo >&2 "Usage: mount_wic_partition <wic_file> [<partition_number> <mount_point> [partition_type]]"
        return 2
    }

    [ -f "${wic_file}" ] || {
        echo >&2 "Can't access image file ${wic_file}"
        return 1
    }

    [ -z "${partition_number}" ] && {
        fdisk -lu "${wic_file}"
        return 0
    }

    [ -z "${mount_point}" ] && {
        echo >&2 "You must specify a mount point"
        return 3
    }

    partition_info=$(sfdisk -d "${wic_file}" | grep ': start=' | grep "${partition_number} : start" | head -1)
    [ -z "${partition_info}" ] && {
        echo >&2 "Partition ${partition_number} not found"
        return 4
    }

    start_sector=$(echo "${partition_info}" | cut -d , -f 1 | cut -d = -f 2)
    sector_count=$(echo "${partition_info}" | cut -d , -f 2 | cut -d = -f 2)
    [ -z "${partition_type}" ] && {
        partition_type=$(echo "${partition_info}" | cut -d , -f 3 | cut -d = -f 2)
        case "$partition_type" in
            c) partition_type=vfat;;
            83) partition_type=ext4;;
            *) echo "Unsupported partition type: ${partition_type}"
               echo "${partition_info}"
               return 5
        esac
    }

    mkdir -p "${mount_point}"
    sudo mount -o loop,ro,offset=$((512*${start_sector})),sizelimit=$((512*${sector_count})) -t ${partition_type} "${wic_file}" "${mount_point}"
}

# mounts the boot rootfs user and userdata partitions of the given wic file
#
explode(){
    local wic=$1
    local mntpt=$2

    mount_wic_partition $wic 1 $mntpt/1 vfat
    mount_wic_partition $wic 2 $mntpt/2 ext4
    mount_wic_partition $wic 5 $mntpt/5 ext4
    mount_wic_partition $wic 6 $mntpt/6 ext4
}

# creates a tarball and md5 file of the given directory
#
implode(){
    local dirname=$1
    local partname=$2
    local curr=$(pwd)
    cd $dirname
    tar -cJf $curr/$partname.tar.xz .
    cd $curr
    md5sum $partname.tar.xz > $partname.tar.xz.md5
}

#Package the difference into the correct tarbal schema
#
packageDiff(){
    cd $TMPDIR/diff
    implode "1" boot
    implode "2" upgrade
    implode "5" user
    implode "6" userdata

    tar -czf $TMPDIR/field/upgrade.tar.gz boot.tar.xz boot.tar.xz.md5 \
    upgrade.tar.xz upgrade.tar.xz.md5 \
    user.tar.xz user.tar.xz.md5 \
    userdata.tar.xz userdata.tar.xz.md5

    outtar="field-upgradeupdate.tar.gz"
    if [ ! -z "$tag" ]; then
        dash="-"
        outtar="$tag$dash$outtar"
    fi     
    cp $TMPDIR/new/3/wigwg/etc/versions.json $TMPDIR/field/upgradeversions.json
    touch $TMPDIR/field/upgradeversions.json
    cd $TMPDIR/field
    md5sum upgrade.tar.gz > upgrade.tar.gz.md5
    tar -czf $CURRDIR/$outtar upgrade.tar.gz upgrade.tar.gz.md5 \
    upgrade.sh install.sh post-install.sh upgradeversions.json
cd $CURRDIR
    echo "Field upgrade output to $outtar"
}

#Setup temporary working space
#
setupTemp(){
    TMPDIR=$(mktemp -d)
    CURRDIR=$(pwd)
    mkdir -p $TMPDIR/old/{1,2,3,5,6}
    mkdir -p $TMPDIR/new/{1,2,3,5,6}
    mkdir $TMPDIR/field
    cp upgrade-scripts/upgrade.sh $TMPDIR/field
    cp upgrade-scripts/install.sh $TMPDIR/field
    cp upgrade-scripts/post-install.sh $TMPDIR/field
}

# unmount partitions and remove temp files
#
cleanup(){
    sudo umount $TMPDIR/old/1
    sudo umount $TMPDIR/old/2
    sudo umount $TMPDIR/old/5
    sudo umount $TMPDIR/old/6
    sudo umount $TMPDIR/new/1
    sudo umount $TMPDIR/new/2
    sudo umount $TMPDIR/new/5
    sudo umount $TMPDIR/new/6
    rm -rf $TMPDIR
}
        
# Main function 
# Takes two input wic files and produces a tarball of their difference that can
# be used in the field upgrade process
# Params:
#  1 - oldwic: .wic file of the base or factory build to be upgraded
#  2 - newwic: .wic file of the new or upgrade build
#  3 - tag:    optional text tag to be prepender to the oouput tarball
# Output:
#  <tag>-field-upgradeupdate.tar.gz

main(){
    oldwic=$1
    newwic=$2
    tag=$3

    #Ensure the correct environment
    if [[ $(id -u) -ne 0 ]]; then 
        echo >&2 "Please run as root"
        exit 2
    fi

    [ -z "${oldwic}" ] && [ -z "${newwic}" ] && {
        echo >&2 "Usage: sudo createUpgrade.sh <old_wic_file> <new_wic_file> [upgrade_tag]"
        exit 2
    }

    if [ ! -f upgrade-scripts/upgrade.sh ]; then
        echo >&2 "Please run within a checkout of scripts-gateway-ww repo."
        echo >&2 "./upgrade-scripts/upgrade.sh needs to exist in the current directory"
        exit 2
    fi

    #Create tmp working space
    setupTemp
    #Mount the partitions of the input wic files
    explode $oldwic $TMPDIR/old
    explode $newwic $TMPDIR/new
    #Diff the two images
    cd $TMPDIR
    sudo rsync -rclkWpg --compare-dest=$TMPDIR/old/ new/ diff
    #Remove files in blacklist
    grep -v '^#' $CURRDIR/upgradeBlacklist.txt | while read f; do
        rm -f "diff/$f" 2>/dev/null
    done
    #Package diff
    packageDiff
    cd $CURRDIR
    #Cleanup the temp working space
    cleanup
}

main "$@"

