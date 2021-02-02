# OSTree-update-scripts
Build scripts and tools for the OSTree firmware images.
To create the images, ostree must either be installed on the system, or within a Docker container.
There are two ways of creating an update image:
   - between two wic images.
   - between OSTree repositories.

These artifacts are produced during the Yocto build.

Scripts are provided for both of these, and instructions for running directly or with Docker. The Docker method has been tested running on an Ubuntu 16.04 machine only.

# Creating an upgrade tarball between wic images

The createOSTreeUpgrade.sh script can be used to create a field upgrade tarball.

```
> ./createOSTreeUpgrade.sh <old-wic> <new-wic> [upgrade-tag]
```

Notes:
  1. The output is a gzipped tarball.
  1. old-wic and new-wic are the *.wic images produced by Yocto build
  1. output is < upgrade-tag ->data.tar.gz
  1. createOSTreeUpdate mounts the partitions from the wic files on loopback devices. 2 free loopback devices are required.

# Creating an upgrade tarball between OSTree repositories

The ostree-delta.py script can be used to create a field upgrade tarball.

```
> ./ostree-delta.py --repo repo --output output-dir [--update_repo repo] [--to_sha sha] [--from_sha sha] [--commit message] [--generate_bin]
```

If using the Docker container use:

```
> ./ostree-delta-docker.sh --repo repo --output output-dir [--update_repo repo] -- [--to_sha sha] [--from_sha sha]  [--commit message] [--generate_bin]
```

   Where:

   - `--repo` base repo folder for upgrade.
   - `--output` output folder for upgrade artifacts.
   - `[--update_repo]` optional repo used if two seperated build trees are to be used.
   - `[--to_sha]` optional text string specifying the base sha for the upgrade.
   - `[--from_sha]` optional text string specifying the base sha for the upgrade.
   - `[--commit]` optional text string used when merging to seperate repositories. Only applicable if ```--update_repo``` is specified.
   - `[--generate_bin]` optional flag to force the data.tar.gz output to be renamed data.bin.

Notes:
  1. The output is a gzipped tarball.
  1. output is named data.tar-gz. If the `--generate_bin` option is provided then the output is renamed to data.bin
