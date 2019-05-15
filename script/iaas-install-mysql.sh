#!/bin/bash
source /etc/xiandian/openrc.sh                         生效环境变量
ping $HOST_IP -c 4 >> /dev/null 2>&1                   ping $HOST_IP 数量为4 将标准输出和错误输出重定向到/dev/null中
if [ 0  -ne  $? ]; then                                 如果上一条命令返回值不等于0则执行以下内容
        echo -e "\033[31m Warning\nPlease make sure the network configuration is correct!\033[0m"    以红色字体向屏幕打印 Warning\nPlease make sure the network configuration is correct!
        exit 1
fi
# check system

sed -i  -e '/server/d' -e "/fudge/d" /etc/ntp.conf                                           将/etc/ntp.conf 文件中有server 和fudge的行删除
sed -i  -e "1i server 127.127.1.0" -e "2i fudge 127.127.1.0 stratum 10" /etc/ntp.conf         在/etc/ntp.conf文件第一行之前添加server 127.127.1.0      在第二行之前添加 fudge 127.127.1.0 stratum 10              
systemctl restart ntpd                                                                           重启ntp服务 
systemctl enable ntpd                                                                             设置ntp服务开机自启


yum install mariadb mariadb-server python2-PyMySQL expect mongodb-server mongodb rabbitmq-server memcached python-memcached -y      安装 mariadb mariadb-server python2-PyMySQL expect mongodb-server mongodb rabbitmq-server memcached python-memcached
sed -i  "/^symbolic-links/a\default-storage-engine = innodb\ninnodb_file_per_table\ncollation-server = utf8_general_ci
\ninit-connect = 'SET NAMES utf8'\ncharacter-set-server = utf8\nmax_connections=10000"/etc/my.cnf                              设置数据库默认存储引擎为innodb  数据库的编码格式为utf8  mariadb最大连接数为10000
crudini --set /usr/lib/systemd/system/mariadb.service Service LimitNOFILE 10000                                                     
crudini --set /usr/lib/systemd/system/mariadb.service Service LimitNPROC 10000
systemctl daemon-reload                          重新载入systemd, 扫描新的或有变的单元
systemctl enable mariadb.service                  设置mariadb服务开机自启
systemctl restart mariadb.service                  重启mariadb服务
expect -c "
spawn /usr/bin/mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$DB_PASS\r\"
expect \"Re-enter new password:\"
send \"$DB_PASS\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"n\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
"
# mongo
sed -i -e '/bind_ip/d' -e 's/#smallfiles.*/smallfiles=true/g' /etc/mongod.conf                           删除/etc/mongod.conf 文件中有bind_ip 一行 并将以#smallfiles.开关的一行替换为smallfiles=true
systemctl enable mongod.service                                                                         设置mogod服务开机自启
systemctl restart mongod.service                                                                          重启mogod服务               
# rabbitmq
systemctl enable rabbitmq-server.service                                                                设置rabbitmq服务开机自启
systemctl restart rabbitmq-server.service                                                                 重启rabbitmq服务
rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS                                                              创建用户 $RABBIT_USER 密码为$RABBIT_PASS
rabbitmqctl set_permissions $RABBIT_USER ".*" ".*" ".*"                                                      对用户授权对本机所有资源有配置，读，写的权限
# memcache
systemctl enable memcached.service                                                                           设置memcache服务开机自启
systemctl restart memcached.service                                                                            重启memcache服务
