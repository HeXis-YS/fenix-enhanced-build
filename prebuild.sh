#!/bin/bash

apt update
apt install -y cmake make m4 g++ pkg-config libssl-dev python-is-python3 python3-distutils python3-venv tcl gyp ninja-build bzip2 libz-dev libffi-dev libsqlite3-dev curl wget default-jdk-headless git mercurial-common sdkmanager zip unzip

curl -s "https://get.sdkman.io" | bash
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle

yes | sdkmanager --licenses
sdkmanager "ndk;${ndk}"
sdkmanager "ndk;21.3.6528147"
sdkmanager "platform-tools"
sdkmanager 'build-tools;31.0.0'
sdkmanager 'build-tools;33.0.0'
sdkmanager 'ndk;25.0.8775105'
sdkmanager 'ndk;25.1.8937393'
