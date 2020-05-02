# upgradeupgrade.sh
# Upgrade 
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
mkfs.ext4 -F -L "upgrades" $dev_upgrade
mount -rw $dev_upgrade $bbmp_upgrade
tar -xzf $UGtarball -C $bbmp_upgrade/
if [[ $? -eq 0 ]]; then
        rm -rf $UGtarball
        rm -rf $UGscript
   echo "Upgrade Succeeded"
fi
cd /
umount $dev_upgrade
e2fsck -y $dev_upgrade

