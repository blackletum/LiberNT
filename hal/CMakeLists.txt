
project(HAL)
if((ARCH STREQUAL "i386") OR (ARCH STREQUAL "amd64"))
    add_subdirectory(halx86)
elseif(ARCH STREQUAL "arm")
    add_subdirectory(halarm)
elseif(ARCH STREQUAL "arm64")
    ## FIXME: Create an import-lib on ARM64 since we don't have a suitable HAL for now.
    spec2def(hal.dll hal.spec ADD_IMPORTLIB)
endif()
