#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh
default_network_id=

#------------------------------------------------------------------------------------------------
printf "\033[35mPlease wait...\n\033[0m"

if [[ `openstack endpoint list | grep -w 'volume' ` == '' ]];then 
	printf "\033[35mPlease install the cinder service first! \n\033[0m"
	exit 1
fi

if [[ `openstack endpoint list | grep -w 'object-store' ` == '' ]];then 
	printf "\033[35mPlease install the swift service first! \n\033[0m"
	exit 1
fi

if [[ `neutron net-list` == '' ]];then 
	printf "\033[35mPlease create network first!\n\033[0m"
	exit 1
fi

if [[ $default_network_id == '' ]]; then
	network_mode=`cat /etc/neutron/plugin.ini |grep ^tenant_network_types |awk -F= '{print $2}'`
	if [[ $network_mode == 'flat' ]];then 
		default_network_id=`neutron net-list |  sed -e '1,3d'  -e '$d' |awk '{print $2}'`
	elif [[ $network_mode == 'gre' ]];then 
		# neutron net-list |  sed -e '1,3d'  -e '$d' |awk '{print $2}'
		for net_name in `neutron net-list |  sed -e '1,3d'  -e '$d' |awk '{print $2}'`;
		do 
			mode=`neutron net-show $net_name |grep "router:external"`
			if [[ `echo $mode |grep -w "False"` !=  "" ]];then
				default_network_id=$net_name
				break
			fi
		done  
	# elif [[ $network_mode == 'vlan' ]] ;then 
	# 	echo 'vlan'
	fi
fi


if [[ `echo $HOST_IP |awk -F. '{print NF}'` != 4 ]];then 
	printf "\033[35mThe environment variable HOST_IP is not a valid IP address\n\033[0m"
	exit 1
fi

mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS trove ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON trove.* TO 'trove'@'localhost' IDENTIFIED BY '$TROVE_DBPASS' ;"
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON trove.* TO 'trove'@'%' IDENTIFIED BY '$TROVE_DBPASS' ;"
yum install openstack-trove-guestagent openstack-trove python-troveclient  openstack-trove-ui -y
openstack user create --domain $DOMAIN_NAME --password $TROVE_PASS trove
openstack role add --project service --user trove admin
openstack service create --name trove --description "Database" database
openstack endpoint create --region RegionOne database public http://$HOST_NAME:8779/v1.0/%\(tenant_id\)s
openstack endpoint create --region RegionOne database internal http://$HOST_NAME:8779/v1.0/%\(tenant_id\)s
openstack endpoint create --region RegionOne database admin http://$HOST_NAME:8779/v1.0/%\(tenant_id\)s

#######################################################################################
####################################     trove     ####################################
#######################################################################################

crudini --set /etc/trove/trove.conf DEFAULT log_dir /var/log/trove
crudini --set /etc/trove/trove.conf DEFAULT log_file trove-api.log
crudini --set /etc/trove/trove.conf DEFAULT trove_auth_url http://$HOST_NAME:35357/v2.0
crudini --set /etc/trove/trove.conf DEFAULT notifier_queue_hostname $HOST_NAME
crudini --set /etc/trove/trove.conf DEFAULT rpc_backend rabbit
crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_user admin
crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_pass $ADMIN_PASS
crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_tenant_name admin
crudini --set /etc/trove/trove.conf DEFAULT nova_compute_service_type compute
crudini --set /etc/trove/trove.conf DEFAULT cinder_service_type volumev2
# crudini --set /etc/trove/trove.conf DEFAULT swift_service_type object-store
crudini --set /etc/trove/trove.conf DEFAULT network_driver trove.network.neutron.NeutronDriver
crudini --set /etc/trove/trove.conf DEFAULT default_neutron_networks $default_network_id
crudini --set /etc/trove/trove.conf DEFAULT auth_strategy keystone
crudini --set /etc/trove/trove.conf DEFAULT add_addresses True
crudini --set /etc/trove/trove.conf DEFAULT network_label_regex \.\*
crudini --set /etc/trove/trove.conf DEFAULT api_paste_config api-paste.ini
crudini --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/trove/trove.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS
crudini --set /etc/trove/trove.conf database connection mysql://trove:$TROVE_DBPASS@$HOST_NAME/trove
crudini --set /etc/trove/trove.conf keystone_authtoken auth_uri http://$HOST_NAME:5000
crudini --set /etc/trove/trove.conf keystone_authtoken auth_url http://$HOST_NAME:35357
crudini --set /etc/trove/trove.conf keystone_authtoken auth_type password
crudini --set /etc/trove/trove.conf keystone_authtoken project_domain_name $DOMAIN_NAME
crudini --set /etc/trove/trove.conf keystone_authtoken user_domain_name $DOMAIN_NAME
crudini --set /etc/trove/trove.conf keystone_authtoken project_name service
crudini --set /etc/trove/trove.conf keystone_authtoken username trove
crudini --set /etc/trove/trove.conf keystone_authtoken password  $TROVE_PASS


#######################################################################################
##########################   trove-taskmanager     ####################################
#######################################################################################

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT log_dir /var/log/trove
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT log_file trove-taskmanager.log
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT trove_auth_url http://$HOST_NAME:5000/v2.0
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_compute_url  http://$HOST_NAME:8774/v2.1
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT notifier_queue_hostname  $HOST_NAME
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT rpc_backend rabbit
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user admin
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $ADMIN_PASS
# crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name service
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_id $(openstack project list |grep -w 'admin' |awk '{print $2}')
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT taskmanager_manager trove.taskmanager.manager.Manager
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT notification_driver messagingv2
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT network_driver trove.network.neutron.NeutronDriver
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT default_neutron_networks $default_network_id
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT network_label_regex \.\*
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT guest_config /etc/trove/trove-guestagent.conf
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT guest_info guest_info.conf
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT injected_config_location /etc/trove/conf.d
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT cloudinit_location /etc/trove/cloudinit
sed -i '/^exists_notification/s/^/#/' /etc/trove/trove-taskmanager.conf 
crudini --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/trove/trove-taskmanager.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS
crudini --set /etc/trove/trove-taskmanager.conf database connection mysql://trove:$TROVE_DBPASS@$HOST_NAME/trove

#######################################################################################
##########################   trove-conductor     ####################################
#######################################################################################
#
crudini --set /etc/trove/trove-conductor.conf DEFAULT log_dir /var/log/trove
crudini --set /etc/trove/trove-conductor.conf DEFAULT log_file trove-conductor.log
crudini --set /etc/trove/trove-conductor.conf DEFAULT trove_auth_url http://$HOST_NAME:5000/v2.0
crudini --set /etc/trove/trove-conductor.conf DEFAULT notifier_queue_hostname  $HOST_NAME
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_user admin
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_pass $ADMIN_PASS
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_tenant_name admin

crudini --set /etc/trove/trove-conductor.conf DEFAULT rpc_backend rabbit
crudini --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/trove/trove-conductor.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS
crudini --set /etc/trove/trove-conductor.conf database connection mysql://trove:$TROVE_DBPASS@$HOST_NAME/trove

#######################################################################################
##########################   trove-guestagent     ####################################
#######################################################################################

crudini --set /etc/trove/trove-guestagent.conf DEFAULT rpc_backend rabbit
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user admin
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass $ADMIN_PASS
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user admin
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_id $(openstack project list |grep -w 'admin' |awk '{print $2}')
crudini --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url http://$HOST_IP:35357/v2.0
crudini --set /etc/trove/trove-guestagent.conf DEFAULT swift_url http://$HOST_IP:8080/v1/AUTH_
crudini --set /etc/trove/trove-guestagent.conf DEFAULT os_region_name RegionOne 
crudini --set /etc/trove/trove-guestagent.conf DEFAULT swift_service_type object-store
crudini --set /etc/trove/trove-guestagent.conf DEFAULT log_file trove-guestagent.log
crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_password $RABBIT_PASS 
crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_host $HOST_IP
crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_userid $RABBIT_USER
crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_port 5672

crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_host $HOST_IP
crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS

su -s /bin/sh -c "trove-manage db_sync" trove
service httpd restart
systemctl enable openstack-trove-api.service openstack-trove-taskmanager.service openstack-trove-conductor.service
systemctl restart openstack-trove-api.service openstack-trove-taskmanager.service openstack-trove-conductor.service


# glance image-create --name "mysql-5.6" --disk-format qcow2  --container-format bare --progress <  MySQL_5.6_xiandian.qcow2  
# trove-manage datastore_update mysql ''
# Glance_Image_ID=$(glance image-list | awk '/ mysql-5.6 / { print $2 }')
# trove-manage datastore_version_update mysql mysql-5.6 mysql ${Glance_Image_ID} '' 1
# FLAVOR_ID=$(openstack flavor list | awk '/ m1.small / { print $2 }')
# trove create mysql-1  ${FLAVOR_ID} --size 5 --databases myDB --users user:r00tme --datastore_version mysql-5.6 --datastore mysql
