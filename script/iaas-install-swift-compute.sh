#!/bin/bash
source /etc/xiandian/openrc.sh
yum install xfsprogs rsync openstack-swift-account openstack-swift-container openstack-swift-object -y
mkfs.xfs -i size=1024 -f /dev/$OBJECT_DISK                  
sed -i '/nodiratime/d' /etc/fstab
echo "/dev/$OBJECT_DISK /swift/node xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
mkdir -p /swift/node
mount /dev/$OBJECT_DISK /swift/node
scp $HOST_NAME:/etc/swift/*.ring.gz /etc/swift/

cat <<EOF > /etc/rsyncd.conf                     配置同步服务器
pid file = /var/run/rsyncd.pid                   pip文件路径
log file = /var/log/rsyncd.log						日志文件路径 
uid = swift											用户id
gid = swift											组id
address = 127.0.0.1									
[account]
path            = /swift/node              
read only       = false
write only      = no
list            = yes
incoming chmod  = 0644
outgoing chmod  = 0644
max connections = 25
lock file =     /var/lock/account.lock
[container]
path            = /swift/node
read only       = false
write only      = no
list            = yes
incoming chmod  = 0644
outgoing chmod  = 0644
max connections = 25
lock file =     /var/lock/container.lock
[object]
path            = /swift/node
read only       = false
write only      = no
list            = yes
incoming chmod  = 0644
outgoing chmod  = 0644
max connections = 25
lock file =     /var/lock/object.lock
[swift_server]
path            = /etc/swift
read only       = true
write only      = no
list            = yes
incoming chmod  = 0644
outgoing chmod  = 0644
max connections = 5
lock file =     /var/lock/swift_server.lock
EOF

systemctl enable rsyncd.service
systemctl restart rsyncd.service


cat <<EOF > /etc/swift/account-server.conf
[DEFAULT]
bind_port = 6002                                 配置account 使用的端口
user = swift										配置account使用的用户	
swift_dir = /etc/swift								配置路径 
devices = /swift/node									配置挂载点
mount_check = false                  
[pipeline:main]
pipeline = healthcheck recon account-server                        启用相关模块
[app:account-server]
use = egg:swift#account
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
[account-replicator]
[account-auditor]
[account-reaper]
[filter:xprofile]
use = egg:swift#xprofile
EOF

cat <<EOF > /etc/swift/container-server.conf
[DEFAULT]
bind_port = 6001
user = swift
swift_dir = /etc/swift
devices = /swift/node
mount_check = false
[pipeline:main]
pipeline = healthcheck recon container-server
[app:container-server]
use = egg:swift#container
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift                    配置rcon缓存目录
[container-replicator]
[container-updater]
[container-auditor]
[container-sync]
[filter:xprofile]
use = egg:swift#xprofile
EOF

cat <<EOF > /etc/swift/object-server.conf
[DEFAULT]
bind_port = 6000
user = swift
swift_dir = /etc/swift
devices = /swift/node
mount_check = false
[pipeline:main]
pipeline = healthcheck recon object-server
[app:object-server]
use = egg:swift#object
[filter:healthcheck]
use = egg:swift#healthcheck
[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift                          配置rcon缓存目录
recon_lock_path = /var/lock										配置lick路径
[object-replicator]
[object-reconstructor]
[object-updater]
[object-auditor]
[filter:xprofile]
use = egg:swift#xprofile
EOF


cat <<EOF > /etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = changeme
swift_hash_path_prefix = changeme
[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange
[swift-constraints]
EOF

chown -R swift:swift /swift/node                  设置挂载点的属主   
mkdir -p /var/cache/swift                       创建rcon目录
chown -R root:swift /var/cache/swift			设置rcon目录的属组
chmod -R 775 /var/cache/swift
chown -R root:swift /etc/swift

systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service
systemctl restart openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service
systemctl enable openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service
systemctl restart openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service
systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl restart openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
