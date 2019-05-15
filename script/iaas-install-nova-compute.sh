#!/bin/bash				声明解释器
source /etc/xiandian/openrc.sh		生效环境变量
ping $HOST_IP -c 4 >> /dev/null 2>&1		 ping $HOST_IP 数量为4 将标准输出和错误输出重定向到/dev/null中
	if [ 0  -ne  $? ]; then                 
	        echo -e "\033[31m Warning\nPlease make sure the network configuration is correct!\033[0m"          以红色字体向屏幕打印 Warning\nPlease make sure the network configuration is correct!
	        exit 1
	fi
# check system

sed -i  -e '/server/d' -e "/fudge/d" /etc/ntp.conf                                                               将/etc/ntp.conf 文件中有server 和fudge的行删除
ntpdate $HOST_IP                                                                                                  向$HOST_IP 同步时间

yum install lvm2 -y																								安装 lvm2 
yum install openstack-nova-compute -y																			安装 openstack-nova-compute
																													
crudini --set /etc/nova/nova.conf DEFAULT rpc_backend  rabbit 													配置后台rpc通信为rabbit
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy   keystone

crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/nova/nova.conf oslo_messaging_rabbit  rabbit_password  $RABBIT_PASS

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$HOST_NAME:5000
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url http://$HOST_NAME:35357
crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/nova/nova.conf keystone_authtoken auth_type password
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name $DOMAIN_NAME
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name $DOMAIN_NAME
crudini --set /etc/nova/nova.conf keystone_authtoken project_name service
crudini --set /etc/nova/nova.conf keystone_authtoken username  nova
crudini --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PASS

crudini --set /etc/nova/nova.conf DEFAULT my_ip $HOST_IP_NODE
crudini --set /etc/nova/nova.conf DEFAULT use_neutron True
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf vnc enabled True                                                          
crudini --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address  $HOST_IP_NODE
crudini --set /etc/nova/nova.conf vnc novncproxy_base_url  http://$HOST_IP:6080/vnc_auto.html

crudini --set /etc/nova/nova.conf glance api_servers http://$HOST_NAME:9292

crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp                            

virt_num=`egrep -c '(vmx|svm)' /proc/cpuinfo`                                                              检查本机是否支持硬件加速                                                  
if [ $virt_num = '0' ];then
	crudini --set /etc/nova/nova.conf libvirt virt_type  qemu
fi
crudini --set /etc/nova/nova.conf libvirt inject_key True
iptables -F
iptables -X
iptables -Z
/usr/libexec/iptables/iptables.init save
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
