#!/bin/bash
source /etc/xiandian/openrc.sh
yum install -y openstack-keystone httpd mod_wsgi         安装 openstack-keystone httpd mod_wsgi 服务


mysql -uroot -p$DB_PASS -e "create database IF NOT EXISTS keystone ;"#创建keystone 数据库   
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS' ;"#授权keystone用户拥有从本地访问keystone数据库的所有权限
mysql -uroot -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS' ;"          授权keystone用户拥有从任何主机访问keystone数据库的所有权限

crudini --set /etc/keystone/keystone.conf database connection  mysql+pymysql://keystone:$KEYSTONE_DBPASS@$HOST_NAME/keystone    修改keystone配置文件中用于数据库连接的内容
ADMIN_TOKEN=$(openssl rand -hex 10)                                                                                                 创建令牌
crudini --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN                                                        将令牌添加到配置文件/etc/keystone/keystone.conf 中 
crudini --set /etc/keystone/keystone.conf token provider  fernet
su -s /bin/sh -c "keystone-manage db_sync" keystone                                                                                       将keystone身份认证服务信息同步到keystone数据库
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone                                                         创建签名密钥和证书
sed -i "s/#ServerName www.example.com:80/ServerName $HOST_NAME/g" /etc/httpd/conf/httpd.conf                              修改/etc/httpd/conf/httpd.conf配置文件将ServerName www.example.com:80 替换为ServerName controller          
cat >/etc/httpd/conf.d/wsgi-keystone.conf<<- EOF                                                                                  将以下内容写入 /etc/httpd/conf.d/wsgi-keystone.conf
Listen 5000                                                                                                                            监听5000端口
Listen 35357																															监听35357端口

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>

EOF

systemctl enable httpd.service                        设置httpd服务开机自启
systemctl start httpd.service                          启动httpd服务

export OS_TOKEN=$ADMIN_TOKEN                           配置admin_token        
export OS_URL=http://$HOST_NAME:35357/v3               配置endpoint的通信地址
export OS_IDENTITY_API_VERSION=3                       配置keystone身份认证服务组件的API版本

openstack service create --name keystone --description "OpenStack Identity" identity         创建keystone身份认证服务组件的service 实体
openstack endpoint create --region RegionOne identity public http://$HOST_NAME:5000/v3        创建keystone身份认证服务组件的 public API endpoint
openstack endpoint create --region RegionOne identity internal http://$HOST_NAME:5000/v3        创建keystone身份认证服务组件的 internal API endpoint  
openstack endpoint create --region RegionOne identity admin http://$HOST_NAME:35357/v3            创建keystone身份认证服务组件的 admin API endpoint

openstack domain create --description "Default Domain" $DOMAIN_NAME                              创建名称为$DOMAIN_NAME 的域 
openstack project create --domain $DOMAIN_NAME --description "Admin Project" admin                创建admin项目
openstack user create --domain $DOMAIN_NAME --password $ADMIN_PASS admin                           创建admin用户，密码为$ADMIN_PASS

openstack role create admin                                                                          创建 admin角色
openstack role add --project admin --user admin admin                                                  将admin role 赋予 admin project 和 admin user  （书上如此）

openstack project create --domain $DOMAIN_NAME --description "Service Project" service                  创建service 项目 该项目属于 $DOMAIN_NAME 域     
openstack project create --domain $DOMAIN_NAME --description "Demo Project" demo                            创建demo 项目 该项目属于 $DOMAIN_NAME 域  

openstack user create --domain $DOMAIN_NAME --password $DEMO_PASS demo                                    创建demo用户 密码为$ADMIN_PASS 该用户属于 $DOMAIN_NAME 域 
openstack role create user                                                                                 创建user role
openstack role add --project demo --user demo user                                                          将user role 赋予 demo project 和 demo user

unset OS_TOKEN OS_URL                                                                                            清除环境变量

cat > /etc/keystone/admin-openrc.sh <<-EOF                                                                      创建admin-openrc.sh 环境变量脚本
export OS_PROJECT_DOMAIN_NAME=$DOMAIN_NAME
export OS_USER_DOMAIN_NAME=$DOMAIN_NAME
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$HOST_NAME:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF



cat > /etc/keystone/demo-openrc.sh <<-EOF                                                                             创建demo-openrc.sh 环境变量脚本
export OS_PROJECT_DOMAIN_NAME=$DOMAIN_NAME
export OS_USER_DOMAIN_NAME=$DOMAIN_NAME
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://$HOST_NAME:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
