#!/bin/bash
USE_OVERWRITE_CFLAGS=0
for arg in "${@}"; do
    if [[ ${arg} = --target=* ]]; then
        USE_OVERWRITE_CFLAGS=1
        if [[ ${arg} != --target=aarch64* ]]; then
            USE_OVERWRITE_CFLAGS=0
        fi
    fi
done

if [[ ${USE_OVERWRITE_CFLAGS} -eq 1 ]]; then
    OVERWRITE_CFLAGS="@OVERWRITE_CFLAGS@"
fi

`dirname ${0}`/@COMPILER_EXE@ "${@}" ${OVERWRITE_CFLAGS}