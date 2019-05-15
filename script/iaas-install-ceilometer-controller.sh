#!/bin/bash
source /etc/xiandian/openrc.sh
source /etc/keystone/admin-openrc.sh

mongo $HOST_NAME/ceilometer --eval "db.addUser({user: 'ceilometer', pwd: '$CEILOMETER_DBPASS', roles: [ 'readWrite', 'dbAdmin' ]})"
while [ $? -ne 0 ]
do
sleep 10
mongo $HOST_NAME/ceilometer --eval "db.addUser({user: 'ceilometer', pwd: '$CEILOMETER_DBPASS', roles: [ 'readWrite', 'dbAdmin' ]})"
done

openstack user create --domain $DOMAIN_NAME --password $CEILOMETER_PASS ceilometer
openstack role add --project service --user ceilometer admin
openstack service create --name ceilometer --description "Telemetry" metering
openstack endpoint create --region RegionOne metering public http://$HOST_NAME:8777
openstack endpoint create --region RegionOne metering internal http://$HOST_NAME:8777
openstack endpoint create --region RegionOne metering admin http://$HOST_NAME:8777

openstack role create ResellerAdmin
openstack role add --project service --user ceilometer ResellerAdmin

yum install -y openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central python-ceilometerclient python-ceilometermiddleware

crudini --set /etc/ceilometer/ceilometer.conf database connection  mongodb://ceilometer:$CEILOMETER_DBPASS@$HOST_NAME:27017/ceilometer
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend rabbit
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password  $RABBIT_PASS

crudini --set /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy keystone
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri  http://$HOST_NAME:5000
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url  http://$HOST_NAME:35357
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken memcached_servers  $HOST_NAME:11211
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_type  password
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_name  $DOMAIN_NAME
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_name $DOMAIN_NAME
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_name  service
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken username  ceilometer
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken password  $CEILOMETER_PASS

crudini --set /etc/ceilometer/ceilometer.conf service_credentials auth_type  password
crudini --set /etc/ceilometer/ceilometer.conf service_credentials auth_url  http://$HOST_NAME:5000/v3
crudini --set /etc/ceilometer/ceilometer.conf service_credentials project_domain_name  $DOMAIN_NAME
crudini --set /etc/ceilometer/ceilometer.conf service_credentials user_domain_name  $DOMAIN_NAME
crudini --set /etc/ceilometer/ceilometer.conf service_credentials project_name  service
crudini --set /etc/ceilometer/ceilometer.conf service_credentials username  ceilometer
crudini --set /etc/ceilometer/ceilometer.conf service_credentials password  $CEILOMETER_PASS
crudini --set /etc/ceilometer/ceilometer.conf service_credentials interface  internalURL
crudini --set /etc/ceilometer/ceilometer.conf service_credentials region_name  RegionOne

systemctl enable openstack-ceilometer-api.service openstack-ceilometer-notification.service openstack-ceilometer-central.service openstack-ceilometer-collector.service
systemctl restart openstack-ceilometer-api.service openstack-ceilometer-notification.service openstack-ceilometer-central.service openstack-ceilometer-collector.service

crudini --set /etc/glance/glance-api.conf  DEFAULT rpc_backend rabbit
crudini --set /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/glance/glance-api.conf  oslo_messaging_rabbit rabbit_password  $RABBIT_PASS
crudini --set /etc/glance/glance-api.conf  oslo_messaging_notifications driver  messagingv2


crudini --set /etc/glance/glance-registry.conf DEFAULT rpc_backend rabbit
crudini --set /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_host $HOST_NAME
crudini --set /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_password  $RABBIT_PASS
crudini --set /etc/glance/glance-registry.conf oslo_messaging_notifications driver  messagingv2

systemctl restart openstack-glance-api.service openstack-glance-registry.service

crudini --set  /etc/cinder/cinder.conf oslo_messaging_notifications driver  messagingv2
systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service

crudini --set /etc/swift/proxy-server.conf  filter:keystoneauth operator_roles "admin, user, ResellerAdmin"
crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "ceilometer catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server"

crudini --set /etc/swift/proxy-server.conf filter:ceilometer paste.filter_factory ceilometermiddleware.swift:filter_factory
crudini --set /etc/swift/proxy-server.conf filter:ceilometer url  rabbit://$RABBIT_USER:$RABBIT_PASS@$HOST_NAME:5672/
crudini --set /etc/swift/proxy-server.conf filter:ceilometer driver  messagingv2
crudini --set /etc/swift/proxy-server.conf filter:ceilometer topic  notifications
crudini --set /etc/swift/proxy-server.conf filter:ceilometer log_level  WARN

systemctl restart openstack-swift-proxy.service
