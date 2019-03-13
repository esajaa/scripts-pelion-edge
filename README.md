# scripts-gateway-ww
Build scripts and tools for the gateway-ww firmware images

# creating an upgrade tarball

The createUpgrade.sh script can be used to create a field upgrade tarball.

```
> sudo createupGrade.sh <old-wic> <new-wic> [upgrade-tag]
```

Notes:
  1. createUpgrade must be run as root as it calls functions such as mount and rsync which require root access
  2. old-wic and new-wic are the *.wic images produced by yocto build
  3. output is < upgrade-tag >-field-upgradeupdate.tar.gz
  4. createUpgrade mounts the partitions from the wic files on loopback devices.  8 free loopback devices are required.  If run within a docker the loopback device must be mapped. Running 'make bash' from wigwag-build-env repo creates a Docker with the correct mapping.
  4. Currently our builds do not include a versions json file.  You may see an error similar to
```
cp: cannot stat '/tmp/tmp.RQDYprC2T9/new/3/wigwg/etc/versions.json': No such file or directory
```
This is expected
