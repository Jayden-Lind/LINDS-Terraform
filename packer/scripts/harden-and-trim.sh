#!/bin/sh
# Hardens the template and removes what a VM does not use. Packer runs it as
# root after the install. LINDS-Ansible roles/common does the same on the
# hosts that it manages (tasks/hardening.yml, tasks/trim.yml): keep the two
# lists the same.
set -eu
export DEBIAN_FRONTEND=noninteractive

installed() {
  dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'
}

# ----- Packages that a VM does not use --------------------------------------
# Hardware services; storage that the template does not have; snap and LXD;
# crash reports and crash dumps (kdump-tools keeps 512 MB of memory for a
# second kernel); timers and services whose output nobody reads; the telnet
# client; kernel trace tools.
candidates="
  modemmanager usbmuxd bolt upower udisks2 fwupd fwupd-signed thermald
  ubuntu-drivers-common open-vm-tools
  multipath-tools open-iscsi mdadm bcache-tools btrfs-progs xfsprogs ntfs-3g
  snapd lxd-installer lxd-agent-loader
  apport apport-symptoms apport-core-dump-handler python3-apport
  kdump-tools kexec-tools makedumpfile
  sysstat landscape-common motd-news-config update-notifier-common sos
  packagekit networkd-dispatcher
  telnet inetutils-telnet
  bpftrace bpfcc-tools trace-cmd
  linux-generic linux-image-generic linux-headers-generic linux-firmware
  intel-microcode amd64-microcode firmware-sof-signed
"
remove=""
for p in $candidates; do
  if installed "$p"; then remove="$remove $p"; fi
done

# The kernel package for a VM must be there before the hardware one goes.
apt-get update
apt-get -y install linux-image-virtual
if [ -n "$remove" ]; then
  # shellcheck disable=SC2086
  apt-get -y purge $remove
fi
headers=$(dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 'linux-headers-*' 'linux-tools-*' 2>/dev/null | awk '$1 == "ii" {print $2}')
if [ -n "$headers" ]; then
  # shellcheck disable=SC2086
  apt-get -y purge $headers
fi
apt-get -y autoremove --purge

# ----- Units whose package must stay -----------------------------------------
# motd-news gets news from motd.ubuntu.com. The ua and esm units are Ubuntu
# Pro, which the hosts do not use. Only NFS version 3 needs rpcbind.
systemctl mask \
  motd-news.timer motd-news.service \
  ua-timer.timer ubuntu-advantage.service esm-cache.service apt-news.service \
  rpcbind.socket rpcbind.service

# ----- Settings ---------------------------------------------------------------
src=/tmp/linds-image
install -o root -g root -m 0644 "$src/01-hardening.conf" /etc/ssh/sshd_config.d/01-hardening.conf
install -o root -g root -m 0644 "$src/90-common-hardening.conf" /etc/sysctl.d/90-common-hardening.conf
install -o root -g root -m 0644 "$src/common-hardening-modules.conf" /etc/modprobe.d/common-hardening-modules.conf
install -o root -g root -m 0644 "$src/90-default-user.cfg" /etc/cloud/cloud.cfg.d/90-default-user.cfg
rm -rf "$src"
/usr/sbin/sshd -t

# The password of the build account. The account keeps its SSH key.
passwd -l jayden

# The purge of kdump-tools removes its GRUB file, but the kernel command line
# keeps crashkernel= until GRUB makes its configuration again.
update-grub
