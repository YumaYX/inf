#!/bin/sh

if [ ! -f /etc/redhat-release ]; then
  exit 1
fi
# vm machine name
dis_name=linux9

# distribution iso
iso_url='https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.3-x86_64-minimal.iso'
iso_url='https://repo.almalinux.org/almalinux/9.3/isos/x86_64/AlmaLinux-9.3-x86_64-minimal.iso'

dnf -y update

# DHCP
# 192.168.255.0/24
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
        }
        else {
            filename "pxelinux.0";
        }
    }
}
DHCPCONFIG

systemctl enable --now dhcpd
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload
systemctl status dhcpd

# TFTP
dnf -y install tftp-server
systemctl enable --now tftp.socket
systemctl enable --now firewalld.service
firewall-cmd --add-service=tftp --permanent
firewall-cmd --reload

# Install SYSLINUX
dnf -y install syslinux

# Copy SYSLINUX bootloaders for Boot TO TFTP
cp -prv /usr/share/syslinux/* /var/lib/tftpboot/

# Mount ISO Image (for pxe, tftp)
curl -o /tmp/${dis_name}.iso ${iso_url}

mkdir -p /var/pxe/${dis_name}
mount -t iso9660 -o loop,ro /tmp/${dis_name}.iso /var/pxe/${dis_name}

# Copy Image Files for Boot TO TFTP
mkdir /var/lib/tftpboot/${dis_name}
cp -prv /var/pxe/${dis_name}/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot/${dis_name}

# Make pxe config file TO TFTP(and PXE)
mkdir /var/lib/tftpboot/pxelinux.cfg

cat <<PXEEOF > /var/lib/tftpboot/pxelinux.cfg/default
default menu.c32
prompt 1
timeout 60

display boot.msg

label linux
  menu label ^Install Linux
  menu default
  kernel ${dis_name}/vmlinuz
  append initrd=${dis_name}/initrd.img ip=dhcp inst.ks=http://192.168.255.2/ks/${dis_name}-ks.cfg
label rescue
  menu label ^Rescue installed system
  kernel ${dis_name}/vmlinuz
  append initrd=${dis_name}/initrd.img rescue
label local
  menu label Boot from ^local drive
  localboot 0xffff
PXEEOF

# httpd
dnf -y install httpd

cat <<APACHEEOF > /etc/httpd/conf.d/pxeboot.conf
Alias /${dis_name} /var/pxe/${dis_name}
<Directory /var/pxe/${dis_name}>
    Options Indexes FollowSymLinks
    #Require ip 127.0.0.1 192.168.255.0/24
    Require all granted
</Directory>
APACHEEOF

# firewalld
dnf -y install firewalld
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --reload
systemctl restart httpd

# Kickstart
mkdir -p /var/www/html/ks

cat <<KICKSTART > /var/www/html/ks/${dis_name}-ks.cfg
text
reboot
url --url=http://192.168.255.2/${dis_name}/

#keyboard --vckeymap=us --xlayouts='us','jp'
keyboard --vckeymap=jp106 --xlayouts='jp','us'

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

pass=$(python3 -c 'import crypt; print(crypt.crypt("root", crypt.METHOD_SHA512))')
echo "rootpw --iscrypted --allow-ssh ${pass}" >> /var/www/html/ks/${dis_name}-ks.cfg
pass=''

chmod 644 /var/www/html/ks/${dis_name}-ks.cfg

exit
