#!/bin/sh

vmname="pxe_ks_linux"
VBoxManage controlvm ${vmname} acpipowerbutton
VBoxManage controlvm ${vmname} poweroff

dir="${HOME}/VirtualBox VMs/${vmname}"

# cpu & memory
cpu=2
cpuexecutioncap=100
mem=$(( 1024 * 2 ))
disk=$(( 1024 * 15 ))

VBoxManage unregistervm ${vmname}
rm -rf "${dir}"
mkdir -p "${dir}"
VBoxManage unregistervm --delete ${vmname}

VBoxManage createvm --name ${vmname} --ostype RedHat_64 --register
VBoxManage modifyvm ${vmname} --cpus ${cpu}
VBoxManage modifyvm ${vmname} --cpuexecutioncap ${cpuexecutioncap}
VBoxManage modifyvm ${vmname} --memory ${mem}
VBoxManage modifyvm ${vmname} --vram 64
VBoxManage modifyvm ${vmname} --graphicscontroller vmsvga
VBoxManage modifyvm ${vmname} --boot1 dvd --boot2 disk --boot3 net --boot4 none

# network
VBoxManage modifyvm ${vmname} --nic1 nat
VBoxManage modifyvm ${vmname} --nic2 intnet
VBoxManage modifyvm ${vmname} --intnet2 "mynetwork"

# storage
# controller
VBoxManage storagectl ${vmname} --name SATA --add sata --controller IntelAHCI
# disk
VBoxManage closemedium disk "${dir}/${vmname}.vdi" --delete
VBoxManage createmedium disk --filename "${dir}/${vmname}.vdi" --size ${disk} --format VDI
# attach
VBoxManage storageattach ${vmname} --storagectl SATA --port 0 --type hdd --medium "${dir}/${vmname}.vdi"

# controller
VBoxManage storagectl ${vmname} --name IDE --add ide --controller PIIX4 --hostiocache on

# run
VBoxManage startvm ${vmname} --type headless

exit
