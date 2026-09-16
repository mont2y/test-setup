#!/usr/bin/env bash

[[ "$INSTALL_VIRTUALIZATION" == true ]] || return 0

log "Installing KVM/QEMU/libvirt/virt-manager"

grep -Eq '(vmx|svm)' /proc/cpuinfo || warn "CPU virtualization flags were not detected; check BIOS/UEFI virtualization settings"

install_package_manifest "packages/virtualization-common.txt"
install_package_manifest "packages/virtualization-${FAMILY}.txt"

if system_service_exists libvirtd.service; then
    enable_system_service_if_exists libvirtd.service
elif system_service_exists virtqemud.service; then
    enable_system_service_if_exists virtqemud.service
    enable_system_service_if_exists virtnetworkd.service
fi

getent group libvirt >/dev/null 2>&1 && sudo usermod -aG libvirt "$USER"
getent group kvm >/dev/null 2>&1 && sudo usermod -aG kvm "$USER"

configure_default_libvirt_network() {
    local networks network_info tmpxml
    # Distinguish a missing network from a failed connection to the system daemon.
    if ! networks="$(sudo env LC_ALL=C virsh --connect qemu:///system net-list --all --name)"; then
        warn 'Could not list libvirt networks; check the system libvirt service'
        return 0
    fi
    if ! grep -Fx default <<< "$networks" >/dev/null; then
        log "Creating libvirt default NAT network"
        if ! tmpxml="$(mktemp --suffix=.xml)"; then
            warn 'Could not create temporary libvirt network definition'
            return 0
        fi
        cat > "$tmpxml" <<'EOF_NET'
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF_NET
        if ! sudo env LC_ALL=C virsh --connect qemu:///system net-define "$tmpxml"; then
            rm -f "$tmpxml"
            warn 'Could not define libvirt default network'
            return 0
        fi
        rm -f "$tmpxml"
    fi
    if ! network_info="$(sudo env LC_ALL=C virsh --connect qemu:///system net-info default)"; then
        warn 'Could not inspect libvirt default network'
        return 0
    fi
    if ! grep -Eq '^Active:[[:space:]]+yes[[:space:]]*$' <<< "$network_info"; then
        if sudo env LC_ALL=C virsh --connect qemu:///system net-start default; then
            ok 'Started libvirt default network'
        else
            warn 'Could not start libvirt default network'
        fi
    fi
    if sudo env LC_ALL=C virsh --connect qemu:///system net-autostart default; then
        ok 'Enabled libvirt default network autostart'
    else
        warn 'Could not enable libvirt default network autostart'
    fi
    if ! network_info="$(sudo env LC_ALL=C virsh --connect qemu:///system net-info default)"; then
        warn 'Could not verify libvirt default network'
        return 0
    fi
    if grep -Eq '^Active:[[:space:]]+yes[[:space:]]*$' <<< "$network_info" &&
       grep -Eq '^Autostart:[[:space:]]+yes[[:space:]]*$' <<< "$network_info"; then
        ok 'Libvirt default network is active with autostart enabled'
    else
        warn "Libvirt default network verification failed (expected Active: yes and Autostart: yes): $network_info"
    fi
}

if command -v virsh >/dev/null 2>&1; then
    configure_default_libvirt_network
else
    warn 'virsh unavailable; cannot configure or verify libvirt default network'
fi
