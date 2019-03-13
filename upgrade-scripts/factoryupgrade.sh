# factoryupgrade.sh
# Factory 
# VERSION 6 (Oct 2016)
color 0 0 0
sleep 1
color 1 0 0
sleep 1
color 0 1 0
sleep 1
color 0 0 1
sleep 1
color 0 1 1
mkfs.ext4 -F -i 4096 -L "factory" $dev_factory
mount $dev_factory $bbmp_factory
mkdir /tmpfs
mount -t tmpfs -o size=409600K,mode=700 tmpfs /tmpfs
echo "expanding $UGtarball to /tmpfs"
tar xzf $UGtarball -C /tmpfs
cd /tmpfs
echo "expanding factory.tar.xz to $bbmp_factory"
tar xJf factory.tar.xz -C $bbmp_factory/
if [[ $? -eq 0 ]]; then
        rm -rf $UGtarball
        rm -rf $UGscript
   echo "Upgrade Succeeded"
   #mkfs.ext4 -F -N 128000 -L "upgrade" $dev_upgrade
   mkfs.ext4 -F -i 4096 -L "upgrade" $dev_upgrade
fi
cd /
umount $dev_factory
echo "checking the filesystems $dev_factory $dev_upgrade"
e2fsck -y $dev_factory
e2fsck -y $dev_upgrade
color 0 0 0

