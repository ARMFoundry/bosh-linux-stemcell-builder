#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

disk_image=${work}/${stemcell_image_name}

if is_ppc64le; then
  # ppc64le guest images have a PReP partition
  # this and other code changes for ppc64le with input from Paulo Flabiano Smorigo @ IBM
  part_offset=2048s
  part_size=9MiB
else
  if is_arm64; then
    # create 99MiB EFI partition, leave 2048s for GPT
    part_offset=1MiB
    part_size=100MiB
  else
    # Reserve the first 63 sectors for grub
    part_offset=63s
    part_size=$((${image_create_disk_size} - 1))
  fi
fi

dd if=/dev/null of=${disk_image} bs=1M seek=${image_create_disk_size} 2> /dev/null
parted --script ${disk_image} mklabel msdos
if is_ppc64le; then
  parted --script ${disk_image} mkpart primary $part_offset $part_size
  parted --script ${disk_image} set 1 boot on
  parted --script ${disk_image} set 1 prep on
  parted --script ${disk_image} mkpart primary ext4 $part_size 100%
else
  if is_arm64; then
    parted --script ${disk_image} mklabel gpt #should overwrite
    parted --script ${disk_image} mkpart primary fat32 $part_offset $part_size
    parted --script ${disk_image} set 1 boot on
    parted --script ${disk_image} mkpart primary ext4 $part_size 100%
  else
    parted --script ${disk_image} mkpart primary ext2 $part_offset $part_size
  fi
fi


# unmap the loop device in case it's already mapped
kpartx -dv ${disk_image}

# Map partition in image to loopback
device=$(losetup --show --find ${disk_image})
add_on_exit "losetup --verbose --detach ${device}"

if is_ppc64le || is_arm64; then
  device_partition=$(kpartx -sav ${device} | grep "^add" | grep "p2 " | grep -v "p1" | cut -d" " -f3)
  boot_device_partition=$(kpartx -sav ${device} | grep "^add" | grep "p1 " | cut -d" " -f3)
else
  device_partition=$(kpartx -sav ${device} | grep "^add" | cut -d" " -f3)
fi
add_on_exit "kpartx -dv ${device}"

loopback_dev="/dev/mapper/${device_partition}"

# Format partition
mkfs.ext4 ${loopback_dev}
# Format EFI partition
if is_arm64; then
  loopback_boot_dev="/dev/mapper/${boot_device_partition}"

  apt-get install -y dosfstools
  mkfs -t vfat ${loopback_boot_dev}
fi

# Mount partition
image_mount_point=${work}/mnt
mkdir -p ${image_mount_point}
mount ${loopback_dev} ${image_mount_point}
add_on_exit "umount ${image_mount_point}"

# Copy root
time rsync -aHA $chroot/ ${image_mount_point}

if is_ppc64le; then
  # Add Xen hypervisor console support
  cat > ${image_mount_point}/etc/init/hvc0.conf <<HVC_CONF

start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]

respawn
exec /sbin/getty -8 38400 hvc0
HVC_CONF
fi
