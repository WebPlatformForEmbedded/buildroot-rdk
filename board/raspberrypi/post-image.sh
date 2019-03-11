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
				cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# fixes rpi3 ttyAMA0 serial console
dtoverlay=pi3-miniuart-bt
__EOF__
			fi
		else
			sed -i 's/ttyAMA0/ttyS0/g' "${BINARIES_DIR}/rpi-firmware/cmdline.txt"
			if ! grep -qE '^enable_uart=1' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
				cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# fixes rpi3 ttyS0 serial console
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
	    --hdmi_mode=*)
		hdmi_mode="${arg:2}"
		if ! grep -qE '^hdmi_mode=' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# hdmi mode 4=720p and 16=1080p
hdmi_group=1
${hdmi_mode}
__EOF__
		else
			sed -e "/^${hdmi_mode%=*}=/s,=.*,=${hdmi_mode##*=}," -i "${BINARIES_DIR}/rpi-firmware/config.txt"
		fi
		;;
		--gpu_mem_256=*|--gpu_mem_512=*|--gpu_mem_1024=*)
		# Set GPU memory
		gpu_mem="${arg:2}"
		sed -e "/^${gpu_mem%=*}=/s,=.*,=${gpu_mem##*=}," -i "${BINARIES_DIR}/rpi-firmware/config.txt"
		;;
		--overclock*)
		if ! grep -qE '^arm_freq=' "${BINARIES_DIR}/rpi-firmware/config.txt"; then
			cat << __EOF__ >> "${BINARIES_DIR}/rpi-firmware/config.txt"

# overclock
[pi0]
[pi0w]
[pi1]
[pi2]
arm_freq=1000
gpu_freq=500
sdram_freq=500
over_voltage=6
[pi3]
arm_freq=1350
gpu_freq=500
sdram_freq=500
over_voltage=5
[pi3+]
arm_freq=1500
gpu_freq=500
sdram_freq=560
over_voltage=5
__EOF__
		fi
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
