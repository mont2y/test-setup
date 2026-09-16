#!/usr/bin/env bash

if [[ "$UPDATE_SYSTEM" == true ]]; then
    log "Updating system"
    case "$FAMILY" in
        debian)
            sudo apt-get update
            sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            ;;
        fedora)
            sudo dnf upgrade --refresh -y
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;
    esac
fi

if [[ "$INSTALL_BASE" == true ]]; then
    install_package_manifest "packages/common.txt"
    install_package_manifest "packages/${FAMILY}.txt"
    install_package_manifest "packages/build-common.txt"
    install_package_manifest "packages/build-${FAMILY}.txt"
fi
