#!/usr/bin/env python3

# Copyright (c) 2021, Pelion Limited and affiliates.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Script to create a static delta bteween 2 ostree repos.

"""

import argparse
import os
import pathlib
import shutil
import subprocess
import sys
import warnings
import tarfile


def warning_on_one_line(message, category, filename, lineno, file=None, line=None):
    """Format a warning the standard way."""
    return "{}:{}: {}: {}\n".format(filename, lineno, category.__name__, message)


def warning(message):
    """
    Issue a UserWarning Warning.

    Args:
    * message: warning's message

    """
    warnings.warn(message, stacklevel=2)
    sys.stderr.flush()


def _execute_command(command, timeout=None):

    print(command)
    p = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=-1,
        universal_newlines=True,
    )
    try:
        output, error = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        ExecuteHelper._print("Timed out after {}s".format(timeout))
        p.kill()
        output, error = p.communicate()

    print(error)

    return output


def _determine_machine_from_repo(repo):

    # Get the refs from the repo, and discard the ones that start "ostree".
    # This is so we can auto-detect the machine tyoe from the repo, which
    # is important for when the repo comes from a compile wic file.

    command = ["ostree", "--repo={}".format(repo), "refs"]
    output = _execute_command(command).rstrip().splitlines()

    machine = None

    # Search through the refs and take the first one that doesn't start
    # with "ostree". This will be the base repo.
    for ref in output:
        if not ref.startswith("ostree"):
            machine = ref
            break
    return machine


def _get_data_from_repo(repo, machine, data):
    # Get the data from the repo

    values = []

    command = ["ostree", "--repo={}".format(repo), "log", machine]
    output = _execute_command(command).rstrip().splitlines()
    for line in output:

        if line.startswith(data):
            values.append(line.split()[1])
    if len(values) > 0:
        return values
    else:
        return None


def _get_shas_from_repo(repo, machine):
    # Get the sha from the repo
    return _get_data_from_repo(repo, machine, "commit")


def _get_version_from_repo(repo, machine):
    # Get the sha from the repo
    return _get_data_from_repo(repo, machine, "Version")


def _generate_metadata(outputpath, from_sha, to_sha):
    # Save the from and to shas into a file. They will be needed on the device at the deploy stage.
    with open(os.path.join(outputpath, "metadata"), "w") as metafile:
        metafile.write("From-sha:{}\n".format(from_sha))
        metafile.write("To-sha:{}\n".format(to_sha))


def _generate_tarball(outputpath):

    command = [
        "tar",
        "-cf",
        "{}/data.tar".format(outputpath),
        "--directory",
        outputpath,
        "--exclude=./data.tar",
        ".",
    ]
    output = _execute_command(command)
    print(output)

    command = ["gzip", "--force", "{}/data.tar".format(outputpath)]
    output = _execute_command(command)
    print(output)


def _generate_static_delta_between_repos(
    repo, update_repo, outputpath, commit, machine, update_sha, from_sha
):
    """
    Generate the static delta information.

    Args:
    * repo        (Path): Initial (deployed) repository.
    * update_repo (Path): New (update) repository. 
    * outputpath  (Path): output folder.
    * commit,
    * machine,
    * update_sha,
    * from_sha,

    """

    # Get the sha from the new repo
    shas = _get_shas_from_repo(update_repo, machine)

    if update_sha is None:
        update_sha = shas[0]
    else:
        if update_sha not in shas:
            warning(
                "sha {} not found in {} for ref {}".format(
                    update_sha, update_repo, machine
                )
            )
            exit(1)

    print(update_sha)

    versions = _get_version_from_repo(update_repo, machine)

    # Get the sha from the deployed repo
    shas = _get_shas_from_repo(repo, machine)

    if from_sha is None:
        from_sha = shas[0]
    else:
        if from_sha not in shas:
            warning("sha {} not found in {} for ref {}".format(from_sha, repo, machine))
            exit(1)

    print(from_sha)

    # Pull the new repo into the old repo.
    command = [
        "ostree",
        "--repo={}".format(repo),
        "pull-local",
        "{}".format(update_repo),
        update_sha,
    ]
    output = _execute_command(command)
    print(output)

    # And commit it.
    command = [
        "ostree",
        "--repo={}".format(repo),
        "commit",
        "-b",
        machine,
        "-s",
        '"{}"'.format(commit),
        "--add-metadata-string=version={}".format(versions[0]),
        "--tree=ref={}".format(update_sha),
    ]
    commit_sha = _execute_command(command).rstrip()
    print(commit_sha)

    _generate_metadata(outputpath, from_sha, commit_sha)

    command = ["ostree", "--repo={}".format(repo), "summary", "-u"]
    output = _execute_command(command)
    print(output)

    output_filename = os.path.join(outputpath, "superblock")

    # Generate the static delta.
    # the max-chunk-size gives the delta in a single data file, called 0
    command = [
        "ostree",
        "--repo={}".format(repo),
        "static-delta",
        "generate",
        machine,
        "--max-chunk-size=2048",
        "--filename={}".format(output_filename),
        "--from",
        from_sha,
        "--to",
        commit_sha,
    ]
    output = _execute_command(command)
    print(output)

    command = ["ostree", "--repo={}".format(repo), "summary", "-u"]
    output = _execute_command(command)
    print(output)

    # Create a tarball.
    _generate_tarball(outputpath)


def _generate_static_delta_between_shas(repo, outputpath, machine, to_sha, from_sha):
    """
    Generate the static delta information.

    Args:
    * repo        (Path): Initial (deployed) repository.
    * outputpath  (Path): output folder.
    * machine,
    * to_sha,
    * from_sha,

    """

    shas = _get_shas_from_repo(repo, machine)

    if len(shas) < 2:
        warning("Not enough commits found is {}".format(repo))
        exit(1)

    if to_sha is None:
        to_sha = shas[0]
    else:
        if to_sha not in shas:
            warning("sha {} not found in {} for ref {}".format(to_sha, repo, machine))
            exit(1)

    if from_sha is None:
        from_sha = shas[1]
    else:
        if from_sha not in shas:
            warning("sha {} not found in {} for ref {}".format(from_sha, repo, machine))
            exit(1)

    _generate_metadata(outputpath, from_sha, to_sha)

    output_filename = os.path.join(outputpath, "superblock")

    # Generate the static delta.
    # the max-chunk-size gives the delta in a single data file, called 0
    command = [
        "ostree",
        "--repo={}".format(repo),
        "static-delta",
        "generate",
        machine,
        "--max-chunk-size=2048",
        "--filename={}".format(output_filename),
        "--from",
        from_sha,
        "--to",
        to_sha,
    ]
    output = _execute_command(command)
    print(output)

    # Create a tarball.
    _generate_tarball(outputpath)


def _str_to_resolved_path(path_str):
    """
    Convert a string to a resolved Path object.

    Args:
    * path_str (str): string to convert to a Path object.

    """
    return pathlib.Path(path_str).resolve(strict=False)


def ensure_is_directory(path):
    """
    Check that a file exists and is a directory.

    Raises an exception on failure and does nothing on success

    Args:
    * path (PathLike): path to check.

    """
    path = pathlib.Path(path)
    if not path.exists():
        raise ValueError('"{}" does not exist'.format(path))
    if not path.is_dir():
        raise ValueError('"{}" is not a directory'.format(path))


def _parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--repo",
        metavar="DIR",
        type=_str_to_resolved_path,
        help="Initial (deployed) repo.",
        required=True,
    )

    parser.add_argument(
        "--output",
        metavar="DIR",
        type=_str_to_resolved_path,
        help="Output Folder. Will be created if necessary.",
        required=True,
    )

    parser.add_argument(
        "--update_repo",
        metavar="DIR",
        type=_str_to_resolved_path,
        help="New (update) repo.",
        required=False,
    )

    parser.add_argument(
        "--machine",
        type=str,
        help="Machine (and therfore ref) being worked on",
        required=False,
    )

    parser.add_argument(
        "--to_sha", type=str, help="sha of the tip of the delta image", required=False
    )

    parser.add_argument(
        "--from_sha",
        type=str,
        help="sha of the base of the delta image",
        required=False,
    )

    parser.add_argument(
        "--commit",
        type=str,
        help="Commit message when merging 2 repos",
        default="OSTree Delta Generation",
        required=False,
    )

    parser.add_argument(
        "--generate_bin",
        action="store_true",
        help="Create a .bin file instead of .tar.gz",
        default=False,
        required=False,
    )

    args, unknown = parser.parse_known_args()

    if len(unknown) > 0:
        warning("unsupported arguments: {}".format(unknown))

    ensure_is_directory(args.repo)

    return args


def main():
    """Script entry point."""
    warnings.formatwarning = warning_on_one_line

    args = _parse_args()

    os.makedirs(args.output, exist_ok=True)

    if args.machine is None:
        machine = _determine_machine_from_repo(repo=args.repo)
    else:
        machine = args.machine

    if args.update_repo is None:
        print(_generate_static_delta_between_shas)
        _generate_static_delta_between_shas(
            repo=args.repo,
            outputpath=args.output,
            machine=machine,
            to_sha=args.to_sha,
            from_sha=args.from_sha,
        )
    else:
        print(_generate_static_delta_between_repos)
        _generate_static_delta_between_repos(
            repo=args.repo,
            update_repo=args.update_repo,
            outputpath=args.output,
            commit=args.commit,
            machine=machine,
            update_sha=args.to_sha,
            from_sha=args.from_sha,
        )

    if args.generate_bin:
        # Rename the tar-gz file to .bin to avoid a "feature" with manifest generation.
        command = [
            "mv",
            "{}/data.tar.gz".format(args.output),
            "{}/data.bin".format(args.output),
        ]
        output = _execute_command(command)
        print(output)


if __name__ == "__main__":
    sys.exit(main())
