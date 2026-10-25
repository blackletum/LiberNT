# ARM64 Hardware Boot Media Configuration
#
# This file defines ARM64 platform boot file paths for build-time embedding.
# The ARM64 profile_raspberry target profile enables Raspberry Pi support.

# Save the directory where this file is located (media/boot) at include time
set(_ARM64_BOOT_MEDIA_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Initialize ARM64 boot file variables (empty by default)
set(ARM64_BOOT_GRAFT_POINTS "")
set(ARM64_BOOT_FILE_DEPS "")

if(ARCH STREQUAL "arm64")
    # Both board driver sets can share an image; PnP selects the hardware.
    option(RPI_SUPPORT "Include Raspberry Pi boot files in ARM64 images" OFF)
    option(RPI3_SUPPORT "Include Raspberry Pi 3 ARM64 drivers" OFF)
    option(RPI5_SUPPORT "Include Raspberry Pi 5 ARM64 drivers" OFF)
    if((RPI3_SUPPORT OR RPI5_SUPPORT) AND NOT RPI_SUPPORT)
        message(FATAL_ERROR "ARM64: a Raspberry Pi board profile requires RPI_SUPPORT")
    endif()

    if(RPI_SUPPORT)
        set(RPI_BOOT_DIR "${_ARM64_BOOT_MEDIA_DIR}/rpi")

        if(NOT EXISTS "${RPI_BOOT_DIR}")
            message(FATAL_ERROR "ARM64: RPI_SUPPORT is ON but boot directory not found: ${RPI_BOOT_DIR}")
        endif()

        message(STATUS "ARM64: Raspberry Pi boot files will be embedded at build time")

        # Verify config.txt exists (central boot configuration for all Pi models)
        if(NOT EXISTS "${RPI_BOOT_DIR}/config.txt")
            message(FATAL_ERROR "ARM64: Required RPi boot file missing: ${RPI_BOOT_DIR}/config.txt")
        endif()

        # Check overlays directory exists
        if(NOT EXISTS "${RPI_BOOT_DIR}/overlays")
            message(FATAL_ERROR "ARM64: Required RPi overlays directory missing: ${RPI_BOOT_DIR}/overlays")
        endif()

        # Collect all boot files: UEFI firmware, device trees, GPU firmware, config
        file(GLOB _RPI_BOOT_FILES
            "${RPI_BOOT_DIR}/*.fd"
            "${RPI_BOOT_DIR}/*.dtb"
            "${RPI_BOOT_DIR}/*.elf"
            "${RPI_BOOT_DIR}/*.dat"
            "${RPI_BOOT_DIR}/*.bin"
            "${RPI_BOOT_DIR}/*.txt"
        )

        file(GLOB _RPI_OVERLAY_FILES
            "${RPI_BOOT_DIR}/overlays/*")

        # Add each file as a graft point (filename=fullpath)
        set(_rpi_file_count 0)
        foreach(_full_path ${_RPI_BOOT_FILES})
            get_filename_component(_file "${_full_path}" NAME)
            list(APPEND ARM64_BOOT_GRAFT_POINTS "${_file}=${_full_path}")
            list(APPEND ARM64_BOOT_FILE_DEPS "${_full_path}")
            math(EXPR _rpi_file_count "${_rpi_file_count} + 1")
        endforeach()

        foreach(_full_path ${_RPI_OVERLAY_FILES})
            if(IS_DIRECTORY "${_full_path}")
                continue()
            endif()

            get_filename_component(_file "${_full_path}" NAME)
            list(APPEND ARM64_BOOT_GRAFT_POINTS "overlays/${_file}=${_full_path}")
            list(APPEND ARM64_BOOT_FILE_DEPS "${_full_path}")
            math(EXPR _rpi_file_count "${_rpi_file_count} + 1")
        endforeach()

        # Set individual file paths for scripts that need them
        set(ARM64_RPI_BOOT_DIR "${RPI_BOOT_DIR}")
        set(ARM64_RPI_CONFIG "${RPI_BOOT_DIR}/config.txt")
        set(ARM64_RPI_OVERLAYS_DIR "${RPI_BOOT_DIR}/overlays")

        message(STATUS "ARM64: RPi boot files validated (${_rpi_file_count} files)")
    endif()

    option(SWITCH_SUPPORT "Build Nintendo Switch SD card images" OFF)

    if(SWITCH_SUPPORT)
        set(SWITCH_BOOT_DIR "${_ARM64_BOOT_MEDIA_DIR}/switch")
        set(SWITCH_HEKATE_INI "${SWITCH_BOOT_DIR}/hekate_ipl.ini")
        if(NOT EXISTS "${SWITCH_HEKATE_INI}")
            message(FATAL_ERROR "ARM64: Required Switch boot file missing: ${SWITCH_HEKATE_INI}")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${SWITCH_HEKATE_INI}")

        set(SWITCH_OPTIONAL_DIR "${SWITCH_BOOT_DIR}/optional")
        file(GLOB_RECURSE SWITCH_OPTIONAL_ENTRIES CONFIGURE_DEPENDS LIST_DIRECTORIES true
             RELATIVE "${SWITCH_OPTIONAL_DIR}" "${SWITCH_OPTIONAL_DIR}/*")
        list(SORT SWITCH_OPTIONAL_ENTRIES)
        if(SWITCH_OPTIONAL_ENTRIES)
            message(STATUS "ARM64: Nintendo Switch SD card layout enabled with the boot files in ${SWITCH_OPTIONAL_DIR}")
        else()
            message(WARNING "ARM64: no Switch boot files in ${SWITCH_OPTIONAL_DIR}. "
                            "LiberNT.img is built without Hekate and its firmware and does not boot; "
                            "run scripts/prepare_switch_boot.sh or scripts/prepare_switch_boot.cmd first")
        endif()
    endif()
endif()
