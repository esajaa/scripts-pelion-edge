# OSTree-update-scripts
Build scripts and tools for the OSTree firmware images.
To create the images, ostree must either be installed on the system, or within a Docker container.
There are two ways of creating an update image:
   - between two wic images.
   - between OSTree repositories.

These artifacts are produced during the Yocto build.

# Creating updates

An OStree update is essentially a delta between a known, deployed, version and the update version. 
It is essential that either the **first image** or **first repository** is preserved for future upgrades. 

## Creating the first update
The first update will be between the **first image** and the update image. 
## Creating subsequent updates
Subsequent updates should be created between the **first image** and the new update image. We can only be sure that the base image is present in a device. We cannot rely on any previous update deltas being applied to a device.


# Creating an update tarball between wic images

The createOSTreeUpgrade.sh script can be used to create a field upgrade tarball.

```
> sudo ./createOSTreeUpgrade.sh old-wic-file new-wic-file delta.tar.gz
```

If using the Docker container use:

```
docker build --no-cache -f Docker/Dockerfile --label ostree-delta  --tag ${USER}/ostree-delta:latest .
docker run --rm -v old-wic-file:/old_wic -v new-wic-file:/new_wic -v /dev:/dev -v ${PWD}:/ws -w /ws --privileged ${USER}/ostree-delta:latest ./createOSTreeUpgrade.sh /old_wic /new_wic delta.tar.gz
```

Notes:
  1. **old-wic-file** and **new-wic-file** are the absolute paths to the .wic images produced by Yocto build. Either the .wic or the .wic.gz file can be used.
  1. The output is stored in the file **delta.tar.gz** in the current folder
  1. createOSTreeUpgrade mounts the partitions from the wic files on loopback devices. 2 free loopback devices are required.
  1. The ```--privileged``` flag is used in the ```docker run``` command to allow mounting of the loopback devices within the container.
  1. If you have built with Docker the output files will be owned by root.  Run ```sudo chown --changes --recursive $USER:$USER .``` to fix it.

# Creating an update tarball between OSTree repositories

The ostree-delta.py script can be used to create a field upgrade tarball.

```
> ./ostree-delta.py --repo repo --output output-dir [--update_repo repo] [--to_sha sha] [--from_sha sha] [--commit message] [--generate_bin]
```

   Where:

   - `--repo repo` is the absolute path to the base repo folder for upgrade.
   - `--output output-dir` is the absolute path to the output folder for upgrade artifacts.
   - `[--update_repo repo]`  is the absolute path to the optional repo used if two seperated build trees are to be used.
   - `[--to_sha]` optional text string specifying the base sha for the upgrade.
   - `[--from_sha]` optional text string specifying the base sha for the upgrade.
   - `[--commit]` optional text string used when merging to seperate repositories. Only applicable if ```--update_repo``` is specified.
   - `[--generate_bin]` optional flag to force the data.tar.gz output to be renamed data.bin.

Notes:
  1. The output is a gzipped tarball in the output-dir folder.
  1. The output is named data.tar-gz. If the `--generate_bin` option is provided then the output is renamed to data.bin

If using the Docker container use:

```
docker build --no-cache -f Docker/Dockerfile --label ostree-delta  --tag ${USER}/ostree-delta:latest .
docker run --rm -v base-repo:/base_repo -v update-repo:/update_repo -v ${PWD}:/ws -w /ws ${USER}/ostree-delta:latest ./ostree-delta.py --repo=/base_repo --update_repo /update_repo --output output-dir
```

   Where:

   - `base-repo`  is the absolute path to the base repo folder for upgrade.
   - `update-repo` is the absolute path to the repo if two seperated build trees are to be used.
   - `output-dir` is the absolute path to the output folder for upgrade artifacts.

Notes:
  1. The output is a gzipped tarball in the output-dir folder.
  1. output is named data.tar-gz.
  1. The output files will be owned by root.  Run ```sudo chown --changes --recursive $USER:$USER .``` to fix it.

# Extracting the ostree repo from a wic image

The extractOSTreeRepo.sh script can be used to extract the OSTree repository from a wic file.

```
> sudo ./extractOSTreeRepo.sh wic-file repo_name 
```

Notes:
  1. **wic-file** is the absolute path to the .wic image produced by Yocto build. Either the .wic or the .wic.gz file can be used.
  1. The output is stored in the folder **repo_name** in the current folder
  1. extractOSTreeRepo mounts the partition from the wic file on a loopback device. 1 free loopback device is required.
  1. The output folder will be owned by root.  Run ```sudo chown --changes --recursive $USER:$USER .``` to fix it.
