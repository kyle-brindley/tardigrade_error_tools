#!/usr/bin/env bash

set -x
# Override default permissions. Set group to rx with no write permissions.
umask 0022

date
script=`basename "$0"`
echo "Running ${script}"

# Deploy master branch against release environment. All other branches against beta.
if [ ${CI_COMMIT_BRANCH} == master ]; then
    environment='release'
    env_alias='sv3r'
    master=true
elif [ ${CI_COMMIT_BRANCH} == dev ]; then
    environment='beta'
    env_alias='sv3b'
    master=false
else
    echo "Unexpected branch name. Exiting..."
    exit 1
fi

# Activate W-13 Python environment
source ./activate_w13pythonenv.sh ${env_alias} ${environment}

# Can treat bash like a scripting language after conda activation
set -Eeuxo pipefail

# For master branch, update tags before building documentation and whl
if ${master}; then
    # Find cmake3 executable
    if [ -x "$(command -v cmake3)" ]; then
        cmake_exec=$(command -v cmake3)
    elif [ -x "$(command -v cmake)" ]; then
        cmake_exec=$(command -v cmake)
    else
        echo "Could not find cmake executable"
        exit 3
    fi
    # Build VERSION file from GetVersionFromGit.cmake without a full CMake configuration
    ${cmake_exec} -D PROJECT_NAME=error_tools -D VERSION_UPDATE_FROM_GIT=True -P src/cmake/GetVersionFromGitTag.cmake
    # GetVersionFromGit.cmake bumps micro/patch version. Retrieve next release from VERSION
    production_version=$(cut -f 1 -d '*' VERSION)
    developer_version=${production_version}+dev
    # Tag production commit and previous developer commit. Continue if already tagged.
    git tag -a ${production_version} -m "production release ${production_version}" || true
    last_merge_hash=$(git log --pretty=format:"%H" --merges -n 2 | tail -n 1)  # Assume last merge was dev->master. Pick previous
    git tag -a ${developer_version} -m "developer release ${developer_version}" ${last_merge_hash} || true
    git push origin --tags
fi

# Build project
./BUILD.sh

# Install project into conda environment by expected whl name.
./INSTALL.sh
