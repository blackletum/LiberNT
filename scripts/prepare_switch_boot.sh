#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Ahmed ARIF <arif193@gmail.com>

set -eu

HEKATE_VERSION=6.5.4
NYX_VERSION=1.9.4
HEKATE_URL=https://github.com/CTCaer/hekate/releases/download/v$HEKATE_VERSION/hekate_ctcaer_${HEKATE_VERSION}_Nyx_$NYX_VERSION.zip
HEKATE_SHA256=a5ee4faa956f1ffe49fdd31d795be3fd556c8dffd9cbed69cec7cff92b8b43f6

WINX_RELEASE=2
WINX_URL=https://github.com/steck0714/winx/releases/download/$WINX_RELEASE/bl33.bin
WINX_SHA256=b68cbcf121415ce7265038306b6a7840cc3cda7316c08f8042c94b88459f1bb6

LAKKA_NAME=Lakka-Switch.aarch64-5.0-devel-20240122151037-5f29696
LAKKA_URL=https://download.switchroot.org/lakka/$LAKKA_NAME.tar
LAKKA_BOOT_OFFSET=1269749760
LAKKA_BOOT_SHA256=ca894c3ed19a52176d6a5bc7fb8b0fcb2a8bc7857ff82aef4a158c57fbe94a65
BL31_SHA256=77b7f5c688934a4d077cd5f39ffaa57383de422652797fd2cdfad67acf41cda4

usage()
{
    echo "Usage: $0" >&2
    echo "Downloads Hekate, the WinX UEFI firmware (BL33) and the Switchroot BL31 into" >&2
    echo "media/boot/switch/optional, which profile_switch images copy onto the SD card." >&2
    exit 2
}

fail()
{
    echo "error: $*" >&2
    exit 1
}

sha256_of()
{
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}

fetch()
{
    url=$1
    file=$2
    sha=$3
    range=${4-}
    if [ -f "$file" ] && [ "$(sha256_of "$file")" = "$sha" ]; then
        return 0
    fi
    echo "Downloading $url"
    rm -f "$file.part"
    if [ -n "$range" ]; then
        curl -fL --retry 3 -r "$range" -o "$file.part" "$url"
    else
        curl -fL --retry 3 -o "$file.part" "$url"
    fi
    got=$(sha256_of "$file.part")
    if [ "$got" != "$sha" ]; then
        rm -f "$file.part"
        fail "$url: SHA-256 $got, expected $sha"
    fi
    mv -f "$file.part" "$file"
}

[ "$#" -eq 0 ] || usage
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
switch_dir=$root/media/boot/switch
downloads=$switch_dir/downloads
optional=$switch_dir/optional
work=$downloads/work
bl31=$work/$LAKKA_NAME/lakka/boot/bl31.bin

mkdir -p "$downloads"
fetch "$HEKATE_URL" "$downloads/hekate.zip" "$HEKATE_SHA256"
fetch "$WINX_URL" "$downloads/winx-bl33.bin" "$WINX_SHA256"
fetch "$LAKKA_URL" "$downloads/lakka-boot.tar" "$LAKKA_BOOT_SHA256" "$LAKKA_BOOT_OFFSET-"

rm -rf "$work" "$optional"
mkdir -p "$work" "$optional/switchroot/winx"
python3 -m zipfile -e "$downloads/hekate.zip" "$work/hekate"
tar -xf "$downloads/lakka-boot.tar" -C "$work" "$LAKKA_NAME/lakka/boot/bl31.bin"
[ "$(sha256_of "$bl31")" = "$BL31_SHA256" ] || fail "bl31.bin does not match the pinned SHA-256"

cp -R "$work/hekate/bootloader" "$optional/bootloader"
cp "$work/hekate/hekate_ctcaer_$HEKATE_VERSION.bin" "$optional/payload.bin"
cp "$downloads/winx-bl33.bin" "$optional/switchroot/winx/bl33.bin"
cp "$bl31" "$optional/switchroot/winx/bl31.bin"
rm -rf "$work"

echo "Switch boot files are ready in $optional:"
(cd "$optional" && find . -type f | sort)
echo "Rebuild the liberntimg target of a profile_switch output tree to include them."
