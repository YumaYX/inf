#!/bin/sh

if [ ! -f /etc/redhat-release ]; then
  exit 1
fi

dis_name=linux9
iso_url='https://repo.almalinux.org/almalinux/9.3/isos/x86_64/AlmaLinux-9.3-x86_64-minimal.iso'

dnf -y update

dnf -y install tftp-server
systemctl enable --now tftp.socket

dnf -y install firewalld
firewall-cmd --permanent --zone=public --add-service=tftp
firewall-cmd --reload

dnf -y install dhcp-server
cat <<DHCPCONFIG > /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
authoritative;

option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;

subnet 192.168.255.0 netmask 255.255.255.0 {
  range dynamic-bootp 192.168.255.200 192.168.255.250;
  option broadcast-address 192.168.255.255;
  option routers 192.168.255.2;
  class "pxeclients" {
    match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
    next-server 192.168.255.2;
    if option architecture-type = 00:07 {
      filename "BOOTX64.EFI";
    } else {
      filename "pxelinux.0";
    }
  }
}
DHCPCONFIG

firewall-cmd --permanent --zone=public --add-service=dhcp
firewall-cmd --reload
systemctl enable --now dhcpd
systemctl restart dhcpd
cat /var/lib/dhcpd/dhcpd.leases

rpmdir=/tmp/rpm
mkdir -p ${rpmdir}
dnf -y reinstall --downloadonly --downloaddir=${rpmdir} shim grub2-efi-x64
cd ${rpmdir} && rpm2cpio shim-x64-*.rpm | cpio -dimv
cd ${rpmdir} && rpm2cpio grub2-efi-x64-*.rpm | cpio -dimv
cp -v ${rpmdir}/boot/efi/EFI/BOOT/BOOTX64.EFI /var/lib/tftpboot/
cp -v ${rpmdir}/boot/efi/EFI/*/grubx64.efi    /var/lib/tftpboot/
chmod 644 /var/lib/tftpboot/{BOOTX64.EFI,grubx64.efi}
ls -ld /var/lib/tftpboot/{BOOTX64.EFI,grubx64.efi}

curl -o /tmp/${dis_name}.iso ${iso_url}

mkdir -p /var/pxe/${dis_name}
mount -t iso9660 -o loop,ro /tmp/${dis_name}.iso /var/pxe/${dis_name}

mkdir /var/lib/tftpboot/${dis_name}
cp -prv /var/pxe/${dis_name}/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot/${dis_name}

cat <<GRUBCONF > /var/lib/tftpboot/grub.cfg
set timeout=5
menuentry "Install ${dis_name}" {
  linuxefi ${dis_name}/vmlinuz ip=dhcp inst.ks=http://192.168.255.2/ks/${dis_name}-ks.cfg
  initrdefi ${dis_name}/initrd.img
}
GRUBCONF

cat /var/lib/tftpboot/grub.cfg
chmod 644 /var/lib/tftpboot/grub.cfg

dnf -y install httpd
systemctl enable --now httpd
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --reload

cat <<APACHEEOF > /etc/httpd/conf.d/pxeboot.conf
Alias /${dis_name} /var/pxe/${dis_name}
<Directory /var/pxe/${dis_name}>
  Options Indexes FollowSymLinks
  Require all granted
</Directory>
APACHEEOF

systemctl restart httpd

mkdir -p /var/www/html/ks

cat <<KICKSTART > /var/www/html/ks/${dis_name}-ks.cfg
text
reboot
url --url=http://192.168.255.2/${dis_name}/

keyboard --vckeymap=jp106 --xlayouts='jp','us'
#keyboard --vckeymap=us --xlayouts='us','jp'
lang en_US.UTF-8

network --bootproto=dhcp --ipv6=auto --activate --hostname=localhost
zerombr

%packages
@core
%end

ignoredisk --only-use=sda
autopart
clearpart --all --initlabel

timezone Asia/Tokyo --utc
KICKSTART

dnf -y install python3

pass=$(python3 -c 'import crypt; print(crypt.crypt("root", crypt.METHOD_SHA512))')
echo "rootpw --iscrypted --allow-ssh ${pass}" >> /var/www/html/ks/${dis_name}-ks.cfg
pass=''

chmod 644 /var/www/html/ks/${dis_name}-ks.cfg
