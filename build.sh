#!/bin/bash
# Set default value
arch_code=2;
o_optimize_level=3;

# Parse arguments
VALID_ARGS=$(getopt -o a:o:p:t: --long arch:,optimize:,platform:,tune: -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -a | --arch)
        export TARGET_ARCH_VARIANT=$2
        shift 2
        ;;
    -o | --optimize)
        case $2 in
            "0" | "1" | "2" | "3")
                o_optimize_level=$2
                ;;
            *)
                echo "$2 is not recognized as a valid value for $1"
                echo "Permitted values are 0, 1, 2, 3"
                exit 1
                ;;
        esac
        shift 2
        ;;
    -p | --platform)
        case $2 in
            "armeabi-v7a" | "x86" | "x86_64")
                echo "Platform $2 is not supported currently"
                exit 1
                ;;
            "arm64-v8a")
                arch_code=2
                ;;
            *)
                echo "$2 is not recognized as a valid value for $1"
                echo "Permitted values are arm64-v8a, AArch64, x86, x86_64"
                exit 1
                ;;
        esac
        shift 2
        ;;
    -t | --tune)
        export TARGET_CPU_VARIANT=$2
        shift 2
        ;;
    --) shift; 
        break 
        ;;
  esac
done

# Set base dir and ndk version
if [ -z "${GITHUB_WORKSPACE}" ]
then
    workdir=$(pwd)/build
else
    workdir=${GITHUB_WORKSPACE}/build
fi
srclib=${workdir}/srclib
# export ANDROID_SDK_ROOT=/opt/android-sdk
# ndk=$(sdkmanager --list | grep -o -P '(?<=ndk;)r[^-]*?(?=[ ]*\|)' | tail -1)
ndk=r21d

# Fenix version
Fenix_version=110.1.0
Fenix_tag=fenix-v${Fenix_version}
Fenix_revision=0
Fenix_code=${Fenix_version//./}${arch_code}${Fenix_revision}

# Component version
FirefoxAndroidAS_tag=v108.0.8
MozAppServices_tag=v96.2.1
MozBuild_commit=2b9af62c807031070f71514858ae83e99dece0bb
MozFennec_tag=FIREFOX_110_0_1_RELEASE
MozGlean_tag=v51.8.2
MozGleanAS_tag=v51.8.2
# rustup_tag=1.25.2
wasisdk_tag=wasi-sdk-19

# Set path
export MOZBUILD_STATE_PATH=${workdir}/.mozbuild
export ANDROID_SDK=/opt/android-sdk
export ANDROID_NDK=/opt/android-sdk/ndk/${ndk}
export ANDROID_HOME=${ANDROID_SDK}
export ANDROID_SDK_ROOT=${ANDROID_SDK}
export ANDROID_SDK_HOME=${ANDROID_SDK}
export ANDROID_NDK_ROOT=${ANDROID_NDK}
export ANDROID_NDK_HOME=${ANDROID_NDK}
export JAVA_HOME="/usr/lib/jvm/default-java"
export PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools

# Optimization flags
mkdir -p ~/.gradle && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.vfs.watch=true -Dorg.gradle.caching=true -Dorg.gradle.configureondemand=true"
export CFLAGS="-DNDEBUG -s -w -O${o_optimize_level} -pipe"
export CXXFLAGS=${CFLAGS}
export RUSTFLAGS="-C opt-level=3 -C codegen-units=1 -C strip=symbols -C debuginfo=0 -C panic=abort"
export CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_DEBUG_LTO=true
if [ -n "${TARGET_ARCH_VARIANT}" ]
then
    export CFLAGS_TUNE="-march=${TARGET_ARCH_VARIANT}"
fi
if [ -n "${TARGET_CPU_VARIANT}" ]
then
    export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C target-cpu=${TARGET_CPU_VARIANT}"
    export CFLAGS_TUNE="${CFLAGS_TUNE} -mtune=${TARGET_CPU_VARIANT}"
fi
export OPT_LEVEL=3

set -o posix ; set

apt update
apt install -y cmake make m4 g++ pkg-config libssl-dev python-is-python3 python3-distutils python3-venv tcl gyp ninja-build bzip2 libz-dev libffi-dev libsqlite3-dev curl wget default-jdk-headless git sdkmanager zip unzip
curl -s "https://get.sdkman.io" | bash
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install gradle 7.5.1

export ANDROID_SDK_ROOT=/opt/android-sdk
yes | sdkmanager --licenses
sdkmanager "ndk;${ndk}"
sdkmanager "ndk;21.3.6528147"
sdkmanager "platform-tools"

# MozBuild
git clone --depth=1 https://github.com/HeXis-YS/fenixbuild.git ${srclib}/MozBuild
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
sed -i -e $'/^.*Build NSPR.*/i sed -i -e \'s/-O[0-3]/${CFLAGS} ${CFLAGS_TUNE}/g\' $(grep -lR -- -O[0-3])' libs/build-nss-android.sh
popd

# MozFennec
pushd ${srclib}
wget --progress=bar:force:noscroll -O MozFennec.zip https://hg.mozilla.org/releases/mozilla-release/archive/${MozFennec_tag}.zip
unzip -o -q MozFennec.zip
rm MozFennec.zip
mv mozilla-release-${MozFennec_tag} MozFennec
popd

# MozGlean
git clone --depth=1 --branch ${MozGlean_tag} https://github.com/mozilla/glean.git ${srclib}/MozGlean
if [ ${MozGlean_tag} == ${MozGleanAS_tag} ]; then
    cp -r ${srclib}/MozGlean ${srclib}/MozGleanAS
fi

# MozGleanAS
if [ ${MozGlean_tag} != ${MozGleanAS_tag} ]; then
    git clone --depth=1 --branch ${MozGleanAS_tag} https://github.com/mozilla/glean.git ${srclib}/MozGleanAS
fi

# rustup
# git clone --depth=1 --branch ${rustup_tag} https://github.com/rust-lang/rustup ${srclib}/rustup
git clone --depth=1 https://github.com/rust-lang/rustup ${srclib}/rustup
pushd ${srclib}/rustup
git fetch --tags
git checkout $(git describe --tags `git rev-list --tags --max-count=1`)
popd

# wasi-sdk
git clone --depth=1 --branch ${wasisdk_tag} https://github.com/WebAssembly/wasi-sdk.git ${srclib}/wasi-sdk
git clone https://git.savannah.gnu.org/git/config.git ${srclib}/wasi-sdk/src/config
pushd ${srclib}/wasi-sdk
git submodule update --init --depth=1
sed -i -e 's/MinSizeRel/Release/g' Makefile
popd

# Fenix
git clone --depth=1 --branch ${Fenix_tag} https://github.com/mozilla-mobile/firefox-android ${workdir}/fenix
pushd ${workdir}/fenix
sed -i -e '/com.google.firebase/d' android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt || sed -i -e '/com.google.firebase/d' android-components/buildSrc/src/main/java/Dependencies.kt
rm -R android-components/components/lib/push-firebase
popd

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
find ${srclib}/MozGlean -name .git -exec rm -rf {} \;
find ${srclib}/MozGleanAS -name .git -exec rm -rf {} \;
find ${srclib}/rustup -name .git -exec rm -rf {} \;
find ${srclib}/wasi-sdk -name .git -exec rm -rf {} \;

${srclib}/MozBuild/build.sh

gradle --stop
cp ${workdir}/fenix/app/build/outputs/apk/release/*.apk /tmp/
