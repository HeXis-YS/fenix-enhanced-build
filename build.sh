#!/bin/bash
# workdir=${HOME}/build
workdir=$(pwd)/build
srclib=${workdir}/srclib
ndk=r21d

Fenix_tag=v107.1.0
Fenix_version=107.1.0
Fenix_code=171020

FirefoxAndroid_tag=v107.0.7
# MozAndroidComponents_tag=v106.0.5
MozAndroidComponentsAS_tag=v104.0.2
MozAppServices_tag=v94.2.2
MozBuild_commit=4c988523b5c24f399150f84d0f681fbbd6502999
MozFennec_tag=FIREFOX_107_0_RELEASE
MozGlean_tag=v51.4.0
MozGleanAS_tag=51.2.0
rustup_tag=1.25.1
wasisdk_tag=wasi-sdk-16

export MOZBUILD_STATE_PATH=${workdir}/.mozbuild
export ANDROID_SDK=/opt/android-sdk
export ANDROID_NDK=/opt/android-sdk/ndk/${ndk}
export ANDROID_HOME=${ANDROID_SDK}
export ANDROID_SDK_ROOT=${ANDROID_SDK}
export ANDROID_SDK_HOME=${ANDROID_SDK}
export ANDROID_NDK_ROOT=${ANDROID_NDK}
export ANDROID_NDK_HOME=${ANDROID_NDK}
export JAVA_HOME="/usr/lib/jvm/default-java"
# export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.vfs.watch=true -Dorg.gradle.caching=true -Dorg.gradle.configureondemand=true"
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.configureondemand=true"

export CFLAGS="-pipe"
export CXXFLAGS="${CFLAGS}"

apt update
apt install -y cmake make m4 g++ pkg-config libssl-dev python-is-python3 python3-distutils python3-venv tcl gyp ninja-build bzip2 libz-dev libffi-dev libsqlite3-dev curl wget default-jdk-headless git mercurial-common sdkmanager zip unzip

mkdir -p ${workdir}
mkdir -p ${srclib}

curl -s "https://get.sdkman.io" | bash
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle

yes | sdkmanager --licenses
sdkmanager "ndk;${ndk}"
sdkmanager "ndk;21.3.6528147"
sdkmanager "platform-tools"

# FireFoxAndroid
git clone https://github.com/mozilla-mobile/firefox-android.git ${srclib}/FireFoxAndroid
pushd ${srclib}/FireFoxAndroid
sed -i -e '/com.google.firebase/d' android-components/buildSrc/src/main/java/Dependencies.kt
rm -fR android-components/components/lib/push-firebase
popd

# MozBuild
git clone https://github.com/HeXis-YS/fenixbuild.git ${srclib}/MozBuild
pushd ${srclib}/MozBuild
git checkout ${MozBuild_commit}
popd

# MozAndroidComponents
# git clone --depth=1 --branch ${MozAndroidComponents_tag} https://github.com/mozilla-mobile/android-components.git ${srclib}/MozAndroidComponents
# pushd ${srclib}/MozAndroidComponents
# sed -i -e '/com.google.android.gms/d; /com.google.firebase/d' buildSrc/src/main/java/Dependencies.kt
# rm -fR components/feature/p2p components/lib/{nearby,push-amazon,push-firebase}
# popd

# MozAndroidComponentsAS
git clone --depth=1 --branch ${MozAndroidComponentsAS_tag} https://github.com/mozilla-mobile/android-components.git ${srclib}/MozAndroidComponentsAS
pushd ${srclib}/MozAndroidComponentsAS
sed -i -e '/com.google.android.gms/d; /com.google.firebase/d' buildSrc/src/main/java/Dependencies.kt
rm -fR components/feature/p2p components/lib/{nearby,push-amazon,push-firebase}
popd

# MozAppServices
git clone --depth=1 --branch ${MozAppServices_tag} https://github.com/mozilla/application-services.git ${srclib}/MozAppServices
pushd ${srclib}/MozAppServices
git submodule update --init --depth=1
popd

# MozFennec
hg clone --stream https://hg.mozilla.org/releases/mozilla-release/ ${srclib}/MozFennec
pushd ${srclib}/MozFennec
hg checkout ${MozFennec_tag}
popd

# MozGlean
git clone --depth=1 --branch ${MozGlean_tag} https://github.com/mozilla/glean.git ${srclib}/MozGlean

# MozGleanAS
git clone --depth=1 --branch ${MozGleanAS_tag} https://github.com/mozilla/glean.git ${srclib}/MozGleanAS

# rustup
git clone --depth=1 --branch ${rustup_tag} https://github.com/rust-lang/rustup ${srclib}/rustup

# wasi-sdk
git clone --depth=1 --branch ${wasisdk_tag} https://github.com/WebAssembly/wasi-sdk.git ${srclib}/wasi-sdk
git clone https://git.savannah.gnu.org/git/config.git ${srclib}/wasi-sdk/src/config
pushd ${srclib}/wasi-sdk
git submodule update --init --depth=1
popd

# Fenix
git clone --depth=1 --branch ${Fenix_tag} https://github.com/mozilla-mobile/fenix ${workdir}/fenix

cd ${workdir}/fenix
${srclib}/MozBuild/prebuild.sh ${Fenix_version} ${Fenix_code}
find ${srclib}/MozBuild -name .git -exec rm -rf {} \;
find ${srclib}/MozAppServices -name .git -exec rm -rf {} \;
find ${srclib}/MozFennec -name .hg -exec rm -rf {} \;
find ${srclib}/MozGlean -name .git -exec rm -rf {} \;
find ${srclib}/MozGleanAS -name .git -exec rm -rf {} \;
find ${srclib}/rustup -name .git -exec rm -rf {} \;
find ${srclib}/wasi-sdk -name .git -exec rm -rf {} \;
# find ${workdir}/ -name gradle.properties -exec sed -i -e 's/org.gradle.parallel=false/org.gradle.parallel=true/g' {} \;
find ${workdir}/ -name gradle.properties -exec sed -i -e 's/org.gradle.daemon=true/org.gradle.daemon=false/g' {} \;
${srclib}/MozBuild/build.sh

gradle --stop
mv ${workdir}/fenix/app/build/outputs/apk/release/*.apk /tmp/
