# scripts-pelion-os-edge
Build scripts and tools for the pelion-os-edge firmware images

# creating an upgrade tarball

The createUpgrade.sh script can be used to create a field upgrade tarball.

```
> sudo createupGrade.sh <old-wic> <new-wic> <upgrade_certificate> <upgrade_key> [upgrade-tag]
```
old_wic_file        - base image for upgrade
new_wic_file        - result image for upgrade
upgrade_certificate - certificate packaged with upgrade used to verify signatures
upgrade_key         - private key for upgrade_certificate used to generate signatures
upgrade_tag         - optional text string prepended to output tarball filename


Notes:
  1. createUpgrade must be run as root as it calls functions such as mount and rsync which require root access
  2. old-wic and new-wic are the *.wic images produced by yocto build
  3. output is < upgrade-tag >-field-upgradeupdate.tar.gz
  4. createUpgrade mounts the partitions from the wic files on loopback devices. 2 free loopback devices are required.  If run within a docker the loopback device must be mapped. Running 'make bash' from wigwag-build-env repo creates a Docker with the correct mapping.

# starting the upgrade process manually

Unpack the field upgrade tarball (usually called `field-upgradeupdate.tar.gz`) into the user partition, under `/slash/upgrades`. (If you unpack the tarball on a Raspberry Pi running the WW image, the full path will be `/mnt/.overlay/user/slash/upgrades`; alternatively, you can mount the SDcard directly on your host under a path of your choice, for faster copying.)
Reboot the device after the unpacking is completed. The upgrade process will start upon detecting the required files.

Note that by default, the user partition is erased during the upgrade. This includes saved settings such as the root password. To disable this behavior, please change the value of `WIPETHEUSER_PARTITION` to `0` in `upgrade.sh` (contained in the field upgrade tarball).
