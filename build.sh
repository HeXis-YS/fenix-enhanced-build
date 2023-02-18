#!/bin/bash
if [ -z "${GITHUB_WORKSPACE}" ]
then
    workdir=$(pwd)/build
else
    workdir=${GITHUB_WORKSPACE}/build
fi
srclib=${workdir}/srclib
ndk=r21d

if [ -z "$1" ]
then
    arch_code=2
else
    arch_code=$1
fi
Fenix_tag=v110.0.1
Fenix_version=110.0.1
Fenix_code=11001${arch_code}0

FirefoxAndroid_tag=components-v110.0.1
FirefoxAndroidAS_tag=v108.0.8
MozAppServices_tag=v96.2.1
MozBuild_commit=c7eb74747e917e0bfb4514f3aa8b715e64740e28
MozFennec_tag=FIREFOX_110_0_RELEASE
MozGlean_tag=v51.8.2
MozGleanAS_tag=v51.8.2
rustup_tag=1.25.2
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
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.vfs.watch=true -Dorg.gradle.caching=true -Dorg.gradle.configureondemand=true"

apt update
apt install -y cmake make m4 g++ pkg-config libssl-dev python-is-python3 python3-distutils python3-venv tcl gyp ninja-build bzip2 libz-dev libffi-dev libsqlite3-dev curl wget default-jdk-headless git mercurial-common sdkmanager zip unzip

mkdir -p ${workdir}
mkdir -p ${srclib}

curl -s "https://get.sdkman.io" | bash
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 7.5.1

yes | sdkmanager --licenses
sdkmanager "ndk;${ndk}"
sdkmanager "ndk;21.3.6528147"
sdkmanager "platform-tools"

# FirefoxAndroid
git clone --depth=1 --branch ${FirefoxAndroid_tag} https://github.com/mozilla-mobile/firefox-android.git ${srclib}/FirefoxAndroid
pushd ${srclib}/FirefoxAndroid
sed -i -e '/com.google.firebase/d' android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt
rm -fR android-components/components/lib/push-firebase
popd

# MozBuild
git clone https://github.com/HeXis-YS/fenixbuild.git ${srclib}/MozBuild
pushd ${srclib}/MozBuild
git checkout ${MozBuild_commit}
popd

# FirefoxAndroidAS
git clone --depth=1 --branch ${FirefoxAndroidAS_tag} https://github.com/mozilla-mobile/firefox-android.git ${srclib}/FirefoxAndroidAS
pushd ${srclib}/FirefoxAndroidAS
sed -i -e '/com.google.firebase/d' android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt || sed -i -e '/com.google.firebase/d' android-components/buildSrc/src/main/java/Dependencies.kt
rm -R android-components/components/lib/push-firebase
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

find ${workdir}/ -name gradle.properties -exec sed -i  \
                                                   -e 's/org.gradle.daemon=true/org.gradle.daemon=false/g' \
                                                   -e 's/org.gradle.parallel=false/org.gradle.parallel=true/g' \
                                                   -e 's/org.gradle.vfs.watch=false/org.gradle.vfs.watch=true/g' \
                                                   -e 's/org.gradle.caching=false/org.gradle.caching=true/g' \
                                                   -e 's/org.gradle.configureondemand=false/org.gradle.configureondemand=true/g' \
                                                   {} \;

cd ${workdir}/fenix
${srclib}/MozBuild/prebuild.sh ${Fenix_version} ${Fenix_code}
find ${srclib}/MozBuild -name .git -exec rm -rf {} \;
find ${srclib}/MozAppServices -name .git -exec rm -rf {} \;
find ${srclib}/MozFennec -name .hg -exec rm -rf {} \;
find ${srclib}/MozGlean -name .git -exec rm -rf {} \;
find ${srclib}/MozGleanAS -name .git -exec rm -rf {} \;
find ${srclib}/rustup -name .git -exec rm -rf {} \;
find ${srclib}/wasi-sdk -name .git -exec rm -rf {} \;

${srclib}/MozBuild/build.sh

gradle --stop
mv ${workdir}/fenix/app/build/outputs/apk/release/*.apk /tmp/
