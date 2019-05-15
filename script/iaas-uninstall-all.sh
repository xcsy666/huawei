#/bin/bash
source /etc/xiandian/openrc.sh
cat <<- EOF

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! Please confirm whether or not to clear all data in the system      !!    
!!                    Please careful operation                        !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
printf "\033[35mPlease Confirm : yes or no !\n\033[0m"
read ans
while [[ "x"$ans != "xyes" && "x"$ans != "xno" ]] 
do
    echo "yes or no"
        read ans
done
if [ "$ans" = no ]; then
exit 1
fi


printf "\033[35mPlease wait ...\n\033[0m"
openstack-service stop   >/dev/null 2>&1
source  /etc/keystone/admin-openrc.sh  >/dev/null 2>&1
for i in `nova list | sed -e '1,3d' -e '$d' |awk '{print $2}'`;do nova delete $i;done >/dev/null 2>&1
for i in `virsh  list  |grep running  |awk '{print $2}'`;do virsh destroy  $i;done >/dev/null 2>&1
for i in `virsh  list --all  | grep -w '-' |awk '{print $2}' `;do virsh undefine $i;done >/dev/null 2>&1
systemctl stop mariadb-server rabbitmq-server openvswitch   >/dev/null 2>&1

if [[ `vgs |grep cinder-volumes` != '' ]];then 
	for i in `lvs |grep volume |awk '{print $1}'`; do
	lvremove -f /dev/cinder-volumes/$i
	done 
	vgremove -f cinder-volumes
	pvremove -f /dev/$BLOCK_DISK
fi

IfSwifExists=`df -h |grep "/swift/node"`
if [[ "$IfSwifExists" != '' ]];then 
	umount /swift/node
        sed -i '/swift/d' /etc/fstab
fi

yum remove -y openstack-* \
python-ceilometerclient python-pecan \
python-ceilometermiddleware vsftpd lvm2 targetcli python-keystone httpd mod_wsgi \
mariadb mariadb-common mariadb-config mariadb-server python2-PyMySQL expect mongodb-server mongodb rabbitmq-server memcached python-memcached \
ebtables ipset openvswitch ebtables xfsprogs rsync \
python-swiftclient python-keystoneclient python-keystonemiddleware memcached ntp crudini  python2-openstacksdk python2-keystoneauth1-2.4.1-1.el7.noarch  httpd-tools \
python-qpid-common qemu* libvirt* virt-* vim-common centos-release-virt-common qemu-kvm-common-ev centos-release-storage-common dhcp-common iaas-xiandian  

rm -rf /etc/sysconfig/network-scripts/ifcfg-br-ex /etc/xiandian/  >/dev/null 2>&1
rm -rf /etc/keystone/ /etc/nova/ /etc/glance/ /etc/neutron/ /etc/openstack-dashboard/  /etc/cinder/ /etc/swift /etc/heat/ /etc/trove/  /etc/mongod.conf  /etc/ntp* /etc/httpd /etc/ceilometer /etc/openvswitch/  >/dev/null 2>&1
rm -rf /var/lib/keystone/ /var/lib/libvirt /var/lib/mongodb /var/lib/rabbitmq/ /etc/aodh/  /var/lib/glance/ /var/lib/nova/ /var/lib/neutron/ /var/lib/cinder/ /var/lib/swift   /var/lib/mysql/ /var/lib/trove >/dev/null 2>&1
rm -rf /etc/my.cnf*  /root/.ssh/known_hosts   >/dev/null 2>&1
service network restart
hostnamectl  set-hostname localhost.localdomain
cat <<EOF > /etc/sysctl.conf    
# System default settings live in /usr/lib/sysctl.d/00-system.conf.
# To override those settings, enter new settings here, or in an /etc/sysctl.d/<name>.conf file
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
EOF
cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
printf "\033[35mPlease wait....\nThe system will reboot immediately ! \nPlease reconnect after system restart ! \n\033[0m"
sleep 3
reboot
