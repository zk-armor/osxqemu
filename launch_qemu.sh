#!/usr/bin/env bash
set -euo pipefail

# Directory the script resides in (used for default paths)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

BASE_DMG=${BASEIMAGE:-"$SCRIPT_DIR/baseImages/BaseSystem_Monterey.dmg"}
BASE_IMG=${BASESYSTEM_IMG:-"$SCRIPT_DIR/BaseSystem.img"}
MAC_DISK=${IMAGE_PATH:-"$SCRIPT_DIR/mac_hdd_ng.img"}
SIZE=${SIZE:-200G}
PID_FILE=${PID_FILE:-"$SCRIPT_DIR/qemu.pid"}

create_images() {
    mkdir -p "$(dirname "$BASE_IMG")"
    if [[ ! -f "$BASE_IMG" ]]; then
        echo "[*] Converting $BASE_DMG to $BASE_IMG"
        qemu-img convert "$BASE_DMG" -O qcow2 -p -c "$BASE_IMG"
    fi

    if [[ ! -f "$MAC_DISK" ]]; then
        echo "[*] Creating disk $MAC_DISK ($SIZE)"
        qemu-img create -f qcow2 "$MAC_DISK" "$SIZE"
    fi
}

start_qemu() {
    sudo chown "$(id -u)":"$(id -g)" /dev/kvm 2>/dev/null || true
    sudo chown -R "$(id -u)":"$(id -g)" /dev/snd 2>/dev/null || true

    local mem="${RAM:-2000}"
    if [[ "${RAM:-}" == "max" ]]; then
        mem=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
    elif [[ "${RAM:-}" == "half" ]]; then
        mem=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 2048 ))
    fi

    qemu-system-x86_64 -m "$mem" \
        -cpu "${CPU:-Penryn}","${CPUID_FLAGS:-vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check,}""${BOOT_ARGS:-}" \
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
        -drive id=InstallMedia,if=none,file="${INSTALL_MEDIA:-$BASE_IMG}",format=qcow2 \
        -drive id=MacHDD,if=none,file="$MAC_DISK",format="${IMAGE_FORMAT:-qcow2}" \
        -device ide-hd,bus=sata.4,drive=MacHDD \
        -netdev user,id=net0,hostfwd=tcp::"${INTERNAL_SSH_PORT:-10022}"-:22,hostfwd=tcp::"${SCREEN_SHARE_PORT:-5900}"-:5900,"${ADDITIONAL_PORTS:-}" \
        -device "${NETWORKING:-vmxnet3}",netdev=net0,id=net0,mac="${MAC_ADDRESS:-52:54:00:09:49:17}" \
        -monitor stdio \
        -boot menu=on \
        -vga vmware \
        "${EXTRA:-}" &

    echo $! > "$PID_FILE"
    wait $!
    rm -f "$PID_FILE"
}

stop_qemu() {
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    else
        pkill -f qemu-system-x86_64 2>/dev/null || true
    fi
}

case "${1:-launch}" in
    create)
        create_images
        ;;
    stop)
        stop_qemu
        ;;
    launch|start)
        create_images
        start_qemu
        ;;
    *)
        echo "Usage: $0 [create|launch|start|stop]" >&2
        exit 1
        ;;
esac
