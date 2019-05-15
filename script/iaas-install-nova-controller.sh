#!/bin/bash                  声明解释器
source /etc/xiandian/openrc.sh                      生效环境变量
source /etc/keystone/admin-openrc.sh                生效环境变量   

mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS nova ;"                       创建nova数据库
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS' ;"       授权nova用户拥有从本地访问nova数据库的所有权限
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS' ;"               授权nova用户拥有从远程访问nova数据库的所有权限
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS nova_api ;"												    创建nova_api数据库		
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS' ;"    授权nova用户拥有从本地访问nova_api数据库的所有权限
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS' ;"			授权nova用户拥有从远程访问nova_api数据库的所有权限

openstack user create --domain $DOMAIN_NAME --password $NOVA_PASS nova													创建nova用户 密码为 $NOVA_DBPASS 属于$DOMAIN_NAME域
openstack role add --project service --user nova admin																	将admin role 赋予 service project 和 nova user  
openstack service create --name nova --description "OpenStack Compute" compute												创建nova计算服务 service entity
openstack endpoint create --region RegionOne compute public http://$HOST_NAME:8774/v2.1/%\(tenant_id\)s                  创建nova计算服务组件的public API endpoint
openstack endpoint create --region RegionOne compute internal http://$HOST_NAME:8774/v2.1/%\(tenant_id\)s                创建nova计算服务组件的internal API endpoint
openstack endpoint create --region RegionOne compute admin http://$HOST_NAME:8774/v2.1/%\(tenant_id\)s						创建nova计算服务组件的admin API endpoint

yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler        安装openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler 服务

crudini --set /etc/nova/nova.conf database connection mysql+pymysql://nova:$NOVA_DBPASS@$HOST_NAME/nova                       配置nova数据库连接
crudini --set /etc/nova/nova.conf api_database connection mysql+pymysql://nova:$NOVA_DBPASS@$HOST_NAME/nova_api					配置nova_api数据库连接

crudini --set /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata                                                  停止使用EC2 API
crudini --set /etc/nova/nova.conf DEFAULT rpc_backend  rabbit                                                                    配置rpc_backend 为 rabbit
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy   keystone																配置认证方式为keystone
crudini --set /etc/nova/nova.conf DEFAULT my_ip $HOST_IP																		配置管理ip为$HOST_IP
crudini --set /etc/nova/nova.conf DEFAULT use_neutron True                                                                        定义nova支持neutron网络服务组件
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver										关闭nova计算服务组件的防火墙功能 
crudini --set /etc/nova/nova.conf DEFAULT metadata_listen 0.0.0.0                                                              定义metadata监听所有ip地址
crudini --set /etc/nova/nova.conf DEFAULT metadata_listen_port 8775																定义metadata监听8775端口

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

crudini --set /etc/nova/nova.conf vnc vncserver_listen $HOST_IP													配置VNC 使用$HOST_IP 为管理地址
crudini --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $HOST_IP									配置VNC 使用$HOST_IP 为数据网络ip地址

crudini --set /etc/nova/nova.conf glance api_servers http://$HOST_NAME:9292                                     配置glance镜像服务所在的地址

crudini --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp									配置lock路径为/var/lib/nova/tmp

su -s /bin/sh -c "nova-manage api_db sync" nova                                                                 将nova计算服务信息同步到 nova_api数据库
su -s /bin/sh -c "nova-manage db sync" nova																		 将nova计算服务信息同步到 nova数据库 
iptables -F																										清除预设表filter 中所有规则链中的规则
iptables -X																										清除预设表filter中使用者自定链中的规则	
iptables -Z																											把所有链的所有计数器归零
/usr/libexec/iptables/iptables.init save																			保存iptables规则	
systemctl enable openstack-nova-api.service  openstack-nova-consoleauth.service openstack-nova-scheduler.service  openstack-nova-conductor.service openstack-nova-novncproxy.service  设置nova服务开机自启
systemctl start openstack-nova-api.service  openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service		开户nova服务
