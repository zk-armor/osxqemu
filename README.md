# macOS on QEMU

This repository was originally a quick redo of [sick.codes](https://github.com/sickcodes/Docker-OSX) Docker/KVM macOS VM. The default workflow used Docker Compose to build and run the VM. This repository now also supports running directly with QEMU without Docker.

## Running with Docker (legacy)

The original Docker setup is still available. It uses a docker volume to persist the macOS image.

```bash
mkdir -p baseImages
cd baseImages
wget https://images.sick.codes/BaseSystem_Monterey.dmg
cd ..
docker-compose build
docker-compose up -d
```

The bootloader should appear shortly after. Run `docker-compose up -d` again whenever you want to restart the VM. The volume is named something like `mysickcodes_disk` (`docker volume ls`). Delete it to start over: `docker volume delete mysickcodes_disk`.

## Running directly with QEMU

To avoid Docker entirely, ensure QEMU and KVM are installed on your host and download the base image as shown above. Then run the included `launch_qemu.sh` script:

```bash
chmod +x launch_qemu.sh
./launch_qemu.sh
```

Environment variables from the Docker setup (e.g. `RAM`, `BOOTDISK`, `NETWORKING`, etc.) are respected. You can override them before executing the script, for example:

```bash
RAM=max NETWORKING=e1000-82545em ./launch_qemu.sh
```

This will start the macOS VM directly with QEMU while preserving the same functionality as the Docker container.
