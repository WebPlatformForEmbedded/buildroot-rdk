#!/bin/bash

set -e

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
GENIMAGE_CFG="${BOARD_DIR}/genimage-${BOARD_NAME}.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
BLUETOOTH="$(grep ^BR2_PACKAGE_BLUEZ5_UTILS=y ${BR2_CONFIG})"

for arg in "$@"
do
	case "${arg}" in
		--add-pi3-miniuart-bt-overlay)
		if [ "x${BLUETOOTH}" = "x" ]; then
			if ! grep -qE '^dtoverlay=' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
				echo "Adding 'dtoverlay=pi3-miniuart-bt' to config.txt (fixes ttyAMA0 serial console)."
				cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# fixes rpi3 ttyAMA0 serial console
dtoverlay=pi3-miniuart-bt
__EOF__
			fi
		else
			echo "Adding serial console to /dev/ttyS0 to config.txt."
			sed -i 's/ttyAMA0/ttyS0/g' "${BINARIES_DIR}/rpi-firmware/cmdline.txt"
			if ! grep -qE '^enable_uart=1' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
				cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# Fixes rpi3 ttyS0 serial console
enable_uart=1
__EOF__
			fi
		fi
		;;
		--aarch64)
		# Run a 64bits kernel (armv8)
		sed -e '/^kernel=/s,=.*,=Image,' -i "${BINARIES_DIR}/rpi-firmware/config.txt"
		if ! grep -qE '^arm_64bit=1' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# enable 64bits support
arm_64bit=1
__EOF__
		fi

		# Enable uart console
		if ! grep -qE '^enable_uart=1' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# enable rpi3 ttyS0 serial console
enable_uart=1
__EOF__
		fi
		;;
		--gpu_mem_256=*|--gpu_mem_512=*|--gpu_mem_1024=*)
		# Set GPU memory
		gpu_mem="${arg:2}"
		sed -e "/^${gpu_mem%=*}=/s,=.*,=${gpu_mem##*=}," -i "${BINARIES_DIR}/rpi-firmware/config.txt"
		;;
	esac

done

if grep -qE '^BR2_TARGET_ROOTFS_EXT2_4=y' "${BR2_CONFIG}"; then
	rm -rf "${GENIMAGE_TMP}"
	genimage                           \
		--rootpath "${TARGET_DIR}"     \
		--tmppath "${GENIMAGE_TMP}"    \
		--inputpath "${BINARIES_DIR}"  \
		--outputpath "${BINARIES_DIR}" \
		--config "${GENIMAGE_CFG}"
elif grep -qE '^BR2_TARGET_ROOTFS_CPIO=y' "${BR2_CONFIG}"; then
	if ! grep -qE '^BR2_TARGET_ROOTFS_INITRAMFS=y' "${BR2_CONFIG}"; then
		sed -i 's/^#initramfs/initramfs/' "${BINARIES_DIR}/rpi-firmware/config.txt"
	else
		sed -i 's/^initramfs/#initramfs/' "${BINARIES_DIR}/rpi-firmware/config.txt"
	fi
	if grep -qE '^BR2_TARGET_ROOTFS_CPIO_XZ=y' "${BR2_CONFIG}"; then
		sed -i 's/cpio.*/cpio.xz/' "${BINARIES_DIR}/rpi-firmware/config.txt"
	elif grep -qE '^BR2_TARGET_ROOTFS_CPIO_LZ4=y' "${BR2_CONFIG}"; then
		sed -i 's/cpio.*/cpio.lz4/' "${BINARIES_DIR}/rpi-firmware/config.txt"
	fi
fi

exit $?
