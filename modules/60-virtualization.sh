#!/usr/bin/env bash

[[ "$INSTALL_VIRTUALIZATION" == true ]] || return 0

log "Installing KVM/QEMU/libvirt/virt-manager"

grep -Eq '(vmx|svm)' /proc/cpuinfo || warn "CPU virtualization flags were not detected; check BIOS/UEFI virtualization settings"

install_package_manifest "packages/virtualization-common.txt"
install_package_manifest "packages/virtualization-${FAMILY}.txt"

if systemctl list-unit-files 2>/dev/null | grep -q '^libvirtd.service'; then
    enable_system_service_if_exists libvirtd.service
elif systemctl list-unit-files 2>/dev/null | grep -q '^virtqemud.service'; then
    enable_system_service_if_exists virtqemud.service
    enable_system_service_if_exists virtnetworkd.service
fi

getent group libvirt >/dev/null 2>&1 && sudo usermod -aG libvirt "$USER"
getent group kvm >/dev/null 2>&1 && sudo usermod -aG kvm "$USER"

if command -v virsh >/dev/null 2>&1; then
    if ! sudo virsh net-info default >/dev/null 2>&1; then
        log "Creating libvirt default NAT network"
        tmpxml="$(mktemp --suffix=.xml)"
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
        sudo virsh net-define "$tmpxml"
        rm -f "$tmpxml"
    fi
    sudo virsh net-start default >/dev/null 2>&1 || true
    sudo virsh net-autostart default >/dev/null 2>&1 || true
fi
