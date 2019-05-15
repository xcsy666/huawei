#!/bin/bash                           声明解释器路径
source /etc/xiandian/openrc.sh          生效环境变量                        
source  /etc/keystone/admin-openrc.sh    生效环境变量
mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS glance ;"             创建glance数据库
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS' ;"        授权glance用户拥有从本地访问glance数据库的所有权限
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS' ;"                 授权glance用户拥有从远程访问glance数据库的所有权限          
yum install -y openstack-glance                                                                                              安装 openstack-glance
openstack user create --domain $DOMAIN_NAME --password $GLANCE_PASS glance                                                      创建glance用户，密码为$GLANCE_PASS                                             
openstack role add --project service --user glance admin                                                                          将admin role 赋予 service project 和 glance user  
openstack service create --name glance --description "OpenStack Image" image                                                        创建glance 镜像的service entity
openstack endpoint create --region RegionOne image public http://$HOST_NAME:9292 													创建glance 镜像服务组件的 public API endpoint
openstack endpoint create --region RegionOne image internal http://$HOST_NAME:9292													创建glance 镜像服务组件的 internal API endpoint
openstack endpoint create --region RegionOne image admin http://$HOST_NAME:9292														创建glance 镜像服务组件的 admin API endpoint

crudini --set /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_NAME/glance          配置glance 数据库连接
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$HOST_NAME:5000                                    配置keystone 身份认证服务组件访问的url
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$HOST_NAME:35357
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers  $HOST_NAME:11211                                 配置memcached_servers url
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password                                                配置keystone 身份认证服务 密码类型
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name $DOMAIN_NAME                                  配置keystone 身份认证服务project_domain_name
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name $DOMAIN_NAME                                     配置keystone 身份认证服务 user_domain_name 
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service                                              配置keystone 身份认证服务 project名称
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance                                                   配置keystone 身份认证服务 用户名为glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password $GLANCE_PASS                                             配置keystone 身份认证服务密码
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone                                                         配置认证服务类型为keystone
crudini --set /etc/glance/glance-api.conf paste_deploy config_file  /usr/share/glance/glance-api-dist-paste.ini                配置paste_deploy 的配置文件路径  
crudini --set /etc/glance/glance-api.conf glance_store stores file,http															配置虚拟机镜像存储的方式
crudini --set /etc/glance/glance-api.conf glance_store $DOMAIN_NAME'_store' file			                                    配置虚拟机镜像存储的形式 														
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/							配置虚拟机镜像存储的路径

crudini --set /etc/glance/glance-registry.conf database connection  mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_NAME/glance     配置数据库连接
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$HOST_NAME:5000                               配置keystone 身份认证服务组件访问的url
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$HOST_NAME:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $HOST_NAME:11211
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name $DOMAIN_NAME
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name $DOMAIN_NAME
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password $GLANCE_PASS
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf paste_deploy config_file  /usr/share/glance/glance-registry-dist-paste.ini

su -s /bin/sh -c "glance-manage db_sync" glance                                                   将glance镜像服务信息同步到glance数据库

systemctl enable openstack-glance-api.service openstack-glance-registry.service               设置glance服务开机自启
systemctl restart openstack-glance-api.service openstack-glance-registry.service           		重启glance服务
