#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

mount --bind /sys $chroot/sys
add_on_exit "umount $chroot/sys"

if is_ppc64le || is_arm64; then
cat > $chroot/etc/apt/sources.list <<EOS
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-updates main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME universe
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-updates universe
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-updates multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-security main restricted
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-security universe
deb http://ports.ubuntu.com/ubuntu-ports/ $DISTRIB_CODENAME-security multiverse
EOS

else

cat > $chroot/etc/apt/sources.list <<EOS
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME main universe multiverse
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu $DISTRIB_CODENAME-security main universe multiverse
EOS

fi

# Upgrade systemd/upstart first, to prevent it from messing up our stubs and starting daemons anyway
if [ ${DISTRIB_CODENAME} == 'xenial' ]; then
   pkg_mgr install systemd
else
   pkg_mgr install upstart
fi
pkg_mgr dist-upgrade

# initscripts messes with /dev/shm -> /run/shm and can create self-referencing symbolic links
# revert /run/shm back to a regular directory (symlinked to by /dev/shm)
rm -rf $chroot/run/shm
mkdir -p $chroot/run/shm
