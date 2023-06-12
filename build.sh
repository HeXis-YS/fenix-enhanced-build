#!/bin/bash
# Set default value
arch_code=2;
TARGET_CPU_VARIANT="cortex-a55"
USE_HG=0
BUILD_DEP=0
SOURCE=0
BUILD=0

# Parse arguments
VALID_ARGS=$(getopt -o t: -l build-dep,source,build,tune:,use-hg -- "${@}")
if [[ ${?} -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
    case "${1}" in
        --build-dep)
            BUILD_DEP=1
            shift
            ;;
        --source)
            SOURCE=1
            shift
            ;;
        --build)
            BUILD=1
            shift
            ;;
        # -a | --arch)
        #     export TARGET_ARCH_VARIANT=${2}
        #     shift 2
        #     ;;
        # -p | --platform)
        #     case ${2} in
        #         "armeabi-v7a" | "x86" | "x86_64")
        #             echo "Platform ${2} is not supported currently"
        #             exit 1
        #             ;;
        #         "arm64-v8a")
        #             arch_code=2
        #             ;;
        #         *)
        #             echo "${2} is not recognized as a valid value for ${1}"
        #             echo "Permitted values are armeabi-v7a, arm64-v8a, x86, x86_64"
        #             exit 1
        #             ;;
        #     esac
        #     shift 2
        #     ;;
        -t | --tune)
            TARGET_CPU_VARIANT=${2}
            shift 2
            ;;
        --use-hg)
            USE_HG=1
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

# Set base dir and ndk version
REPO_DIR=$(realpath $(dirname ${0}))
if [[ -n "${GITHUB_WORKSPACE}" ]]; then
    WORK_DIR=${GITHUB_WORKSPACE}/build
else
    WORK_DIR=${REPO_DIR}/build
fi
SRCLIB=${WORK_DIR}/srclib
mkdir -p ${SRCLIB}

# Fenix version
Fenix_version=114.0.0
Fenix_tag=fenix-v114.0
Fenix_revision=0
Fenix_code=${Fenix_version//./}${arch_code}${Fenix_revision}

# Component version
FirefoxAndroidAS_tag=components-v112.2.0
MozAppServices_tag=v114.1
MozBuild_commit=ac484e39fa24c43cf805d8e19c9cdd18c2914f59
MozFennec_tag=FIREFOX_114_0_RELEASE
MozGlean_tag=v52.7.0
MozGleanAS_tag=v52.6.0
rustup_tag=1.26.0
wasisdk_tag=wasi-sdk-16

# Set path
export MOZBUILD_STATE_PATH=${WORK_DIR}/.mozbuild
export ANDROID_SDK=/opt/android-sdk
export ANDROID_NDK=/opt/android-sdk/ndk/r21d
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
export RUSTFLAGS="-C opt-level=3 -C codegen-units=1 -C strip=symbols -C debuginfo=0 -C panic=abort"
export CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_DEBUG_LTO=true
export OPT_LEVEL=3
OVERWRITE_CFLAGS="-O3"
# if [ -n "${TARGET_ARCH_VARIANT}" ]; then
#     OVERWRITE_CFLAGS="${OVERWRITE_CFLAGS} -march=${TARGET_ARCH_VARIANT}"
# fi
if [ -n "${TARGET_CPU_VARIANT}" ]; then
    OVERWRITE_CFLAGS="${OVERWRITE_CFLAGS} -mcpu=${TARGET_CPU_VARIANT} -mtune=${TARGET_CPU_VARIANT}"
    export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C target-cpu=${TARGET_CPU_VARIANT}"
fi

# set -o posix ; set

if [[ ${BUILD_DEP} -eq 1 ]]; then
    sudo apt update
    sudo apt install -y cmake make m4 g++ pkg-config libssl-dev python-is-python3 python3-distutils python3-venv tcl gyp ninja-build bzip2 libz-dev libffi-dev libsqlite3-dev curl wget default-jdk-headless git sdkmanager zip unzip rsync
    curl -s "https://get.sdkman.io" | bash
fi

export SDKMAN_DIR="${HOME}/.sdkman"
[[ -s "${HOME}/.sdkman/bin/sdkman-init.sh" ]] && source "${HOME}/.sdkman/bin/sdkman-init.sh"

if [[ ${BUILD_DEP} -eq 1 ]]; then
    sdk install gradle 7.5.1

    yes | sdkmanager --licenses
    sdkmanager 'ndk;r21d' 'ndk;r25' 'ndk;r25b' 'ndk;r25c' 'platform-tools' 'build-tools;31.0.0' 'build-tools;33.0.0' 'build-tools;33.0.1'
    #                      GleanAS   Glean
    rm -rf ~/.cache/sdkmanager/*.zip /tmp/.sdkmanager*  # Delete sdkmanager temporary files
    pushd ${ANDROID_SDK_ROOT}/ndk
    ln -s r21d 21.3.6528147
    ln -s r25  25.0.8775105
    ln -s r25b 25.1.8937393
    ln -s r25c 25.2.9519653
    popd

    git clone -b ndk-r26-release --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "${WORK_DIR}/llvm-prebuilts"
    for ndk in "r21d" "r25" "r25b" "r25c"; do
        pushd "${ANDROID_SDK}/ndk/${ndk}/toolchains/llvm/prebuilt/linux-x86_64"
        xargs -a "${REPO_DIR}/filelist/${ndk}.txt" -I{} rm -f "{}"
        find . -type d -empty -delete
        rsync -a "${WORK_DIR}/llvm-prebuilts/clang-r475365b/" ./

        pushd bin
        sed -i -e "s|/clang|/wrapper/clang|g" *-linux-android*-clang*
        mkdir -p wrapper
        for file in "clang" "clang++"; do
            cp "${REPO_DIR}/ndk-wrapper.sh" wrapper/${file}
            sed -i -e "s|@COMPILER_EXE@|${file}|g" -e "s|@OVERWRITE_CFLAGS@|${OVERWRITE_CFLAGS}|g" wrapper/${file}
        done
        chmod 755 wrapper/*
        popd
        popd
    done
    rm -rf "${WORK_DIR}/llvm-prebuilts"
fi

if [[ ${SOURCE} -eq 1 ]]; then
    # MozBuild
    git clone -b wrapper --depth=1 https://github.com/HeXis-YS/fenixbuild.git ${SRCLIB}/MozBuild
    pushd ${SRCLIB}/MozBuild
    git checkout ${MozBuild_commit}
    popd

    # FirefoxAndroidAS
    git clone --depth=1 --branch ${FirefoxAndroidAS_tag} https://github.com/mozilla-mobile/firefox-android.git ${SRCLIB}/FirefoxAndroidAS
    pushd ${SRCLIB}/FirefoxAndroidAS
    sed -i -e '/com.google.firebase/d' android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt || sed -i -e '/com.google.firebase/d' android-components/buildSrc/src/main/java/Dependencies.kt
    rm -R android-components/components/lib/push-firebase
    popd

    # MozAppServices
    git clone --depth=1 --branch ${MozAppServices_tag} https://github.com/mozilla/application-services.git ${SRCLIB}/MozAppServices
    pushd ${SRCLIB}/MozAppServices
    git submodule update --init --depth=1
    popd

    # MozFennec
    if [[ ${USE_HG} -eq 1 ]]; then
        python3 -m pip install --user --upgrade mercurial
        hg clone --stream https://hg.mozilla.org/releases/mozilla-release/ ${SRCLIB}/MozFennec
        pushd ${SRCLIB}/MozFennec
        hg checkout ${MozFennec_tag}
        popd
    else
        pushd ${SRCLIB}
        wget --progress=bar:force:noscroll -O MozFennec.zip https://hg.mozilla.org/releases/mozilla-release/archive/${MozFennec_tag}.zip
        unzip -o -q MozFennec.zip
        rm MozFennec.zip
        mv mozilla-release-${MozFennec_tag} MozFennec
        popd
    fi


    # MozGlean
    git clone --depth=1 --branch ${MozGlean_tag} https://github.com/mozilla/glean.git ${SRCLIB}/MozGlean
    if [[ ${MozGlean_tag} == ${MozGleanAS_tag} ]]; then
        cp -r ${SRCLIB}/MozGlean ${SRCLIB}/MozGleanAS
    fi

    # MozGleanAS
    if [[ ${MozGlean_tag} != ${MozGleanAS_tag} ]]; then
        git clone --depth=1 --branch ${MozGleanAS_tag} https://github.com/mozilla/glean.git ${SRCLIB}/MozGleanAS
    fi

    # rustup
    git clone --depth=1 --branch ${rustup_tag} https://github.com/rust-lang/rustup ${SRCLIB}/rustup

    # wasi-sdk
    git clone --depth=1 --branch ${wasisdk_tag} https://github.com/WebAssembly/wasi-sdk.git ${SRCLIB}/wasi-sdk
    git clone https://git.savannah.gnu.org/git/config.git ${SRCLIB}/wasi-sdk/src/config
    pushd ${SRCLIB}/wasi-sdk
    git submodule update --init --depth=1
    popd

    # Fenix
    git clone --depth=1 --branch ${Fenix_tag} https://github.com/mozilla-mobile/firefox-android ${WORK_DIR}/fenix
    pushd ${WORK_DIR}/fenix
    sed -i -e '/com.google.firebase/d' android-components/plugins/dependencies/src/main/java/DependenciesPlugin.kt || sed -i -e '/com.google.firebase/d' android-components/buildSrc/src/main/java/Dependencies.kt
    rm -R android-components/components/lib/push-firebase
    popd

    find ${WORK_DIR}/ -name gradle.properties -exec sed -i  \
                                                    -e 's/org.gradle.daemon=true/org.gradle.daemon=false/g' \
                                                    -e 's/org.gradle.parallel=false/org.gradle.parallel=true/g' \
                                                    -e 's/org.gradle.configureondemand=false/org.gradle.configureondemand=true/g' \
                                                    {} \;

    cd ${WORK_DIR}/fenix
    ${SRCLIB}/MozBuild/prebuild.sh ${Fenix_version} ${Fenix_code}
    find ${SRCLIB}/MozBuild -name .git -exec rm -rf {} \;
    find ${SRCLIB}/MozAppServices -name .git -exec rm -rf {} \;
    find ${SRCLIB}/MozGlean -name .git -exec rm -rf {} \;
    find ${SRCLIB}/MozGleanAS -name .git -exec rm -rf {} \;
    find ${SRCLIB}/rustup -name .git -exec rm -rf {} \;
    find ${SRCLIB}/wasi-sdk -name .git -exec rm -rf {} \;
fi

if [[ ${BUILD} -eq 1 ]]; then
    cd ${WORK_DIR}/fenix
    ${SRCLIB}/MozBuild/build.sh

    gradle --stop
    cp ${WORK_DIR}/fenix/app/build/outputs/apk/release/*.apk /tmp/
fi
