#!/bin/bash
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

echo workdir=${workdir}
echo srclib=${srclib}
echo ndk=${ndk}

Fenix_version=110.0.1
Fenix_tag=v${Fenix_version}
Fenix_revision=2

echo Fenix_version=${Fenix_version}
echo Fenix_tag=${Fenix_tag}
echo Fenix_revision=${Fenix_revision}

function get_dependencies {
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
}


function get_source {
    # Component version
    FirefoxAndroid_tag=components-v110.0.1
    FirefoxAndroidAS_tag=v108.0.8
    MozAppServices_tag=v96.2.1
    MozBuild_commit=ae3f653bfe716c1a74fb94b91fb51899dcc14b05
    MozFennec_tag=FIREFOX_110_0_RELEASE
    MozGlean_tag=v51.8.2
    MozGleanAS_tag=v51.8.2
    # rustup_tag=1.25.2
    wasisdk_tag=wasi-sdk-19

    echo FirefoxAndroid_tag=${FirefoxAndroid_tag}
    echo FirefoxAndroidAS_tag=${FirefoxAndroidAS_tag}
    echo MozAppServices_tag=${MozAppServices_tag}
    echo MozBuild_commit=${MozBuild_commit}
    echo MozFennec_tag=${MozFennec_tag}
    echo MozGlean_tag=${MozGlean_tag}
    echo MozGleanAS_tag=${MozGleanAS_tag}
    echo rustup_tag=${rustup_tag}
    echo wasisdk_tag=${wasisdk_tag}

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
    pushd ${srclib}
    wget -O MozFennec.zip https://hg.mozilla.org/releases/mozilla-release/archive/${MozFennec_tag}.zip
    unzip -o -q MozFennec.zip
    rm MozFennec.zip
    mv mozilla-release-${MozFennec_tag} MozFennec
    popd

    # MozGlean
    git clone --depth=1 --branch ${MozGlean_tag} https://github.com/mozilla/glean.git ${srclib}/MozGlean

    # MozGleanAS
    git clone --depth=1 --branch ${MozGleanAS_tag} https://github.com/mozilla/glean.git ${srclib}/MozGleanAS

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
}

function build {
    # Fenix version
    if [ -z "$1" ]
    then
        arch_code=2
    else
        arch_code=$1
    fi
    Fenix_code=${Fenix_version//./}${arch_code}${Fenix_revision}
    export SDKMAN_DIR="$HOME/.sdkman"
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

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

    echo MOZBUILD_STATE_PATH=${MOZBUILD_STATE_PATH}
    echo ANDROID_SDK=${ANDROID_SDK}
    echo ANDROID_NDK=${ANDROID_NDK}
    echo ANDROID_HOME=${ANDROID_HOME}
    echo ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
    echo ANDROID_SDK_HOME=${ANDROID_SDK_HOME}
    echo ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}
    echo ANDROID_NDK_HOME=${ANDROID_NDK_HOME}
    echo JAVA_HOME=${JAVA_HOME}
    echo PATH=${PATH}


    # Optimization flags
    mkdir -p ~/.gradle && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties
    export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.vfs.watch=true -Dorg.gradle.caching=true -Dorg.gradle.configureondemand=true"
    export CFLAGS="-DNDEBUG -s -w -O3 -pipe"
    export CXXFLAGS=${CFLAGS}
    export RUSTFLAGS="-C opt-level=3 -C codegen-units=1 -C strip=symbols -C debuginfo=0 -C panic=abort"
    export CARGO_PROFILE_RELEASE_LTO=true
    export CARGO_PROFILE_DEBUG_LTO=true
    if [ -n "$2" ]
    then
        export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C target-cpu=$2"
    fi
    export OPT_LEVEL=3

    echo GRADLE_OPTS=${GRADLE_OPTS}
    echo CFLAGS=${CFLAGS}
    echo CXXFLAGS=${CXXFLAGS}
    echo RUSTFLAGS=${RUSTFLAGS}
    echo CARGO_PROFILE_RELEASE_LTO=${CARGO_PROFILE_RELEASE_LTO}
    echo CARGO_PROFILE_DEBUG_LTO=${CARGO_PROFILE_DEBUG_LTO}
    echo CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS=${CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS}
    echo OPT_LEVEL=${OPT_LEVEL}

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
}

case $1 in
    "ci-dependency")
        get_dependencies
        ;;
    "ci-source")
        get_source
        ;;
    "ci-build")
        build $2 $3
        ;;
    "build")
        get_dependencies
        get_source
        build $2 $3
        ;;
    *)
        echo "Unknown command $1" >&2
        exit 1
    ;;
esac
