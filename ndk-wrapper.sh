#!/bin/bash
new_args=()
OVERWRITE_CFLAGS="@OVERWRITE_CFLAGS@"
USE_OVERWRITE_CFLAGS=0
for arg in "${@}"; do
    if [[ ${arg} = --target=* ]]; then
        USE_OVERWRITE_CFLAGS=1
        if [[ ${arg} != --target=aarch64* ]]; then
            USE_OVERWRITE_CFLAGS=0
        fi
    elif [[ $arg == -march* ]]; then
        continue
    fi
    new_args+=("$arg")
done

if [[ ${USE_OVERWRITE_CFLAGS} -eq 1 ]]; then
    `dirname ${0}`/@COMPILER_EXE@ "${new_args[@]}" ${OVERWRITE_CFLAGS}
else
    `dirname ${0}`/@COMPILER_EXE@ "${@}"
fi
