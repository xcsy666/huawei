#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh
crudini --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  physnet1
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges physnet1:$minvlan:$maxvlan
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid
systemctl restart neutron-server 

ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex $INTERFACE_NAME 
cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME <<EOF
DEVICE=$INTERFACE_NAME
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
EOF
systemctl restart network
crudini --set  /etc/neutron/l3_agent.ini DEFAULT  external_network_bridge  br-ex 
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings  physnet1:br-ex

systemctl restart neutron-openvswitch-agent 
systemctl restart neutron-l3-agent 

echo -e "\033[31m\nCreate a sample vlan network\n\033[0m "
neutron net-create ext-net --router:external True --provider:physical_network physnet1 --provider:network_type flat
neutron net-create demo-net --tenant-id  `openstack project list |grep -w admin |awk '{print $2}'` --provider:network_type vlan
