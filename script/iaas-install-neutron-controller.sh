#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh

mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS neutron ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS' ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS' ;"

openstack user create --domain $DOMAIN_NAME --password $NEUTRON_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://$HOST_NAME:9696
openstack endpoint create --region RegionOne network internal http://$HOST_NAME:9696
openstack endpoint create --region RegionOne network admin http://$HOST_NAME:9696

yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables  openstack-neutron-openvswitch
crudini --set /etc/neutron/neutron.conf database connection  mysql://neutron:$NEUTRON_DBPASS@$HOST_NAME/neutron
crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  $RABBIT_PASS

crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin  ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins  router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://$HOST_NAME:5000
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url  http://$HOST_NAME:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers  $HOST_NAME:11211
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type  password
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name  $DOMAIN_NAME
crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name $DOMAIN_NAME
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name  service
crudini --set /etc/neutron/neutron.conf keystone_authtoken username  neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken password  $NEUTRON_PASS

crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True
crudini --set /etc/neutron/neutron.conf  nova auth_url  http://$HOST_NAME:35357
crudini --set /etc/neutron/neutron.conf  nova auth_type  password
crudini --set /etc/neutron/neutron.conf  nova project_domain_name  $DOMAIN_NAME
crudini --set /etc/neutron/neutron.conf  nova user_domain_name  $DOMAIN_NAME
crudini --set /etc/neutron/neutron.conf  nova region_name  RegionOne
crudini --set /etc/neutron/neutron.conf  nova project_name  service
crudini --set /etc/neutron/neutron.conf  nova username  nova
crudini --set /etc/neutron/neutron.conf  nova password  $NOVA_PASS
crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,gre,vxlan,local
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  openvswitch,l2population
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers  port_security

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group true
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid

crudini --set  /etc/neutron/l3_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set  /etc/neutron/l3_agent.ini DEFAULT external_network_bridge 

crudini --set  /etc/neutron/dhcp_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq
crudini --set  /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata  True

crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent prevent_arp_spoofing True
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup  firewall_driver iptables_hybrid

crudini --set  /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip  $HOST_IP
crudini --set  /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret  $METADATA_SECRET
crudini --set  /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_port 8775

crudini --set  /etc/nova/nova.conf DEFAULT auto_assign_floating_ip True
crudini --set  /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0
crudini --set  /etc/nova/nova.conf DEFAULT metadata_listen_port 8775
crudini --set  /etc/nova/nova.conf DEFAULT scheduler_default_filters 'AvailabilityZoneFilter,RamFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter'
crudini --set  /etc/nova/nova.conf DEFAULT compute_driver libvirt.LibvirtDriver
crudini --set  /etc/nova/nova.conf neutron  url  http://$HOST_NAME:9696
crudini --set  /etc/nova/nova.conf neutron  auth_url  http://$HOST_NAME:35357
crudini --set  /etc/nova/nova.conf neutron  auth_type  password
crudini --set  /etc/nova/nova.conf neutron  project_domain_name  $DOMAIN_NAME
crudini --set  /etc/nova/nova.conf neutron  user_domain_name  $DOMAIN_NAME
crudini --set  /etc/nova/nova.conf neutron  region_name  RegionOne
crudini --set  /etc/nova/nova.conf neutron  project_name  service
crudini --set  /etc/nova/nova.conf neutron  username  neutron
crudini --set  /etc/nova/nova.conf neutron  password  $NEUTRON_PASS
crudini --set  /etc/nova/nova.conf neutron  service_metadata_proxy  True
crudini --set  /etc/nova/nova.conf neutron  metadata_proxy_shared_secret  $METADATA_SECRET

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf 
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf 
echo 'net.ipv4.conf.all.rp_filter=0' >> /etc/sysctl.conf
sysctl -p 

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

systemctl restart openvswitch
systemctl enable openvswitch
ovs-vsctl add-br br-int 
systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service    neutron-openvswitch-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl restart neutron-server.service   neutron-openvswitch-agent neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl enable neutron-l3-agent.service
systemctl restart neutron-l3-agent.service
