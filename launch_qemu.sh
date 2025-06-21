#!/usr/bin/env bash
set -eux

# Adjust permissions for KVM and sound
sudo chown    "$(id -u)":"$(id -g)" /dev/kvm 2>/dev/null || true
sudo chown -R "$(id -u)":"$(id -g)" /dev/snd 2>/dev/null || true

# Dynamic RAM size handling
[[ "${RAM}" = max ]] && export RAM="$(( "$(head -n1 /proc/meminfo | tr -dc '[:digit:]')" / 1000000 ))"
[[ "${RAM}" = half ]] && export RAM="$(( "$(head -n1 /proc/meminfo | tr -dc '[:digit:]')" / 2000000 ))"

sudo chown -R "$(id -u)":"$(id -g)" /dev/snd 2>/dev/null || true

exec qemu-system-x86_64 -m "${RAM:-2000}" \
    -cpu "${CPU:-Penryn}","${CPUID_FLAGS:-vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check,}""${BOOT_ARGS}" \
    -machine q35,"${KVM-'accel=kvm:tcg'}" \
    -smp "${CPU_STRING:-${SMP:-1},cores=${CORES:-1}}" \
    -usb -device usb-kbd -device usb-tablet \
    -device isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal\(c\)AppleComputerInc \
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE:-./OVMF_CODE.fd}" \
    -drive if=pflash,format=raw,file="${OVMF_VARS:-./OVMF_VARS-1024x768.fd}" \
    -smbios type=2 \
    -audiodev "${AUDIO_DRIVER:-alsa}",id=hda -device ich9-intel-hda -device hda-duplex,audiodev=hda \
    -device ich9-ahci,id=sata \
    -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="${BOOTDISK:-./OpenCore/OpenCore.qcow2}" \
    -device ide-hd,bus=sata.2,drive=OpenCoreBoot \
    -device ide-hd,bus=sata.3,drive=InstallMedia \
    -drive id=InstallMedia,if=none,file="${INSTALL_MEDIA:-./BaseSystem.img}",format=qcow2 \
    -drive id=MacHDD,if=none,file="${IMAGE_PATH:-./mac_hdd_ng.img}",format="${IMAGE_FORMAT:-qcow2}" \
    -device ide-hd,bus=sata.4,drive=MacHDD \
    -netdev user,id=net0,hostfwd=tcp::"${INTERNAL_SSH_PORT:-10022}"-:22,hostfwd=tcp::"${SCREEN_SHARE_PORT:-5900}"-:5900,"${ADDITIONAL_PORTS}" \
    -device "${NETWORKING:-vmxnet3}",netdev=net0,id=net0,mac="${MAC_ADDRESS:-52:54:00:09:49:17}" \
    -monitor stdio \
    -boot menu=on \
    -vga vmware \
    "${EXTRA:-}"
