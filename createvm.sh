#!/bin/bash 

##############################################################################
# Script created several VM (configurable)
#
# Should be started from root
# Assuming that Guest OS is Ubuntu 16.04 and cloud image located in BOOT_DIR
#
# Tested with CentOS Linux release 7.4.1708 (Core) with installed KVM and virsh
#
##############################################################################

Q_TY_of_VM=2
VM_BASE=vm0
FQDN_BASE=porn.novostavskiy.kiev.ua
RAM=2048
VCPU=1
OS_VAR=ubuntu16.04
USERNAME=jin
#assuming that id_rsa.pub generated alredy
#need to be updated to check and generate key if missed
#readonly SSH_KEY=$(cat "~${USERNAME}/.ssh/id_rsa.pub")	
SSH_KEY=$(cat /home/$USERNAME/.ssh/id_rsa.pub)
IP_ADD_BASE=192.168.122.1
BASE_DIR=/var/lib/libvirt
BOOT_DIR=$BASE_DIR/boot
IMAGE_DIR=$BASE_DIR/images

createvm () {

echo "creating VM" $1

VM_NAME=$VM_BASE$1
IP_ADD=$IP_ADD_BASE$1/24

virsh list --all | grep $VM_NAME
if [ $? -eq 0 ]; then 
		echo "VM" $1 "exist"
	else
		rm -f $IMAGE_DIR/$VM_NAME/*
		rm -f user-data meta-data *cidata.iso
		cp $BOOT_DIR/*.img $IMAGE_DIR/$VM_NAME/$VM_NAME.img
		echo "instance-id: " $VM_NAME >  $IMAGE_DIR/$VM_NAME/meta-data
		echo "local-hostname: " $VM_NAME >>  $IMAGE_DIR/$VM_NAME/meta-data
		echo "#cloud-config" >  $IMAGE_DIR/$VM_NAME/user-data
		echo "# Hostname management" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "preserve_hostname: False" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "hostname: " $VM_NAME >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "fqdn: " $VM_NAME.$FQDN_BASE >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "# Users ">>  $IMAGE_DIR/$VM_NAME/user-data
		echo "users:" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "    - default " >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "    - name: " $USERNAME  >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "      groups: ['admin']" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "      shell: /bin/bash" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "      sudo: ALL=(ALL) NOPASSWD:ALL">>  $IMAGE_DIR/$VM_NAME/user-data
		echo "      ssh-authorized-keys:" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "        - " $SSH_KEY  >>  $IMAGE_DIR/$VM_NAME/user-data
		echo ""  >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "# network/interfaces"  >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "write_files: " >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "  - content: |" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       auto lo" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       iface lo inet loopback" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       auto ens3" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       iface ens3 inet static" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       address " $IP_ADD >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       gateway 192.168.122.1" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "       dns-nameservers 192.168.122.1" >>  $IMAGE_DIR/$VM_NAME/user-data	#to be updated
		echo "    path: /etc/network/interfaces" >>  $IMAGE_DIR/$VM_NAME/user-data		#to be updated
		echo "" >>  $IMAGE_DIR/$VM_NAME/user-data
		echo "    path: /etc/network/interfaces" >> $IMAGE_DIR/$VM_NAME/user-data	
		echo "runcmd: " >> $IMAGE_DIR/$VM_NAME/user-data
		echo "  - [ sudo, service, networking, restart ] " >> $IMAGE_DIR/$VM_NAME/user-data
		echo "  - sudo echo " $IP_ADD_BASE$1 $VM_NAME  ">> /etc/hosts" >> $IMAGE_DIR/$VM_NAME/user-data
                echo "  - sudo ifdown ens3 && sudo ifup ens3 " >> $IMAGE_DIR/$VM_NAME/user-data
		cp $IMAGE_DIR/$VM_NAME/user-data ./
		cp $IMAGE_DIR/$VM_NAME/meta-data ./
		mkisofs -o  $IMAGE_DIR/$VM_NAME/$VM_NAME-cidata.iso -V cidata -J -r user-data meta-data
		qemu-img create -f qcow2 -o preallocation=metadata $IMAGE_DIR/$VM_NAME/$VM_NAME.new.image 20G
		virt-resize --quiet --expand /dev/sda1 $IMAGE_DIR/$VM_NAME/$VM_NAME.img $IMAGE_DIR/$VM_NAME/$VM_NAME.new.image 
		mv $IMAGE_DIR/$VM_NAME/$VM_NAME.new.image $IMAGE_DIR/$VM_NAME/$VM_NAME.img
		virsh pool-create-as --name $VM_NAME --type dir --target $IMAGE_DIR/$VM_NAME/
		virt-install --import --name $VM_NAME --memory $RAM --vcpus $VCPU --cpu host --disk $IMAGE_DIR/$VM_NAME/$VM_NAME.img,format=qcow2,bus=virtio --disk $IMAGE_DIR/$VM_NAME/$VM_NAME-cidata.iso,device=cdrom --network bridge=virbr0,model=virtio --os-type=linux --os-variant=$OS_VAR --graphics spice --noautoconsole
sleep 180
fi
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

for i in 1 $Q_TY_of_VM
do 
 mkdir -p $IMAGE_DIR/vm0$i
 createvm $i &>>/var/vm.err.log
 #sleep 180 
done 


