#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre									设置租户网络的类型为gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000							配置gre为private network 提供的标识范围				

ovs-vsctl add-br br-ex																								添加一个名为br-ex的网桥
ovs-vsctl add-port br-ex $INTERFACE_NAME 																			为网桥br-ex添加一个名为$INTERFACE_NAME 的接口
cat > /etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME <<EOF													为文件	/etc/sysconfig/network-scripts/ifcfg-$INTERFACE_NAME 覆盖写入以下内容
DEVICE=$INTERFACE_NAME																								物理设备的名字为$INTERFACE_NAME
TYPE=Ethernet																										网络类型为Ethernet
BOOTPROTO=none																										禁用dhcp	
ONBOOT=yes																											引导时激活该设备
EOF
systemctl restart network
crudini --set  /etc/neutron/l3_agent.ini DEFAULT  external_network_bridge  br-ex
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings  physnet1:br-ex
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types  gre
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $HOST_IP
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs  enable_tunneling True
crudini --set  /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings external:br-ex

systemctl restart neutron-server 
systemctl restart neutron-l3-agent neutron-openvswitch-agent 
