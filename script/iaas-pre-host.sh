#/bin/bash                                                                 此脚本用/bin/bash来解释执行
source /etc/xiandian/openrc.sh                                           #加载openrc.sh 文件，自动生成环境变量
# config env network
systemctl  stop firewalld.service                                         #关防火墙
systemctl  disable  firewalld.service >> /dev/null 2>&1					#设置防火墙开机不自启
systemctl stop NetworkManager >> /dev/null 2>&1                        #关闭networkmanager服务
systemctl disable NetworkManager >> /dev/null 2>&1						#关闭networkmanager服务开机自启
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config           修改selinux配置文件设置selinux 的状态为permissive
setenforce 0                                                              临时设置selinux模式为permissive
yum remove -y NetworkManager firewalld                                     删除 NetworkManager 和 firewalld 服务
service network restart                                                    重启网络服务
#----  ntp  ---------------------------------
yum install ntp  iptables-services  -y                                      安装ntp 和 iptables-services服务
if [ 0  -ne  $? ]; then
	echo -e "\033[31mThe installation source configuration errors\033[0m"
	exit 1
fi
systemctl enable iptables                                             设置iptables开机自启
systemctl restart iptables                                             重启iptables 服务
iptables -F                                                           清除预设表filter 中所有规则链中的规则
iptables -X                                                           清除预设表filter中使用者自定链中的规则
iptables -z                                                            把所有链的所有计数器归零
service iptables save                                                 保存防火墙规则
# install package
sed -i -e 's/#UseDNS yes/UseDNS no/g' -e 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config     关闭dns域名解析 关闭gssapi 认证
yum upgrade -y                                                                                                                 升级所有包
yum -y install openstack-selinux python-openstackclient crudini -y                                         安装    openstack-selinux python-openstackclient crudini
if [[ `ip a |grep -w $HOST_IP ` != '' ]];then     
	hostnamectl set-hostname $HOST_NAME
elif [[ `ip a |grep -w $HOST_IP_NODE ` != '' ]];then 
	hostnamectl set-hostname $HOST_NAME_NODE
else
	hostnamectl set-hostname $HOST_NAME
fi
sed -i -e "/$HOST_NAME/d" -e "/$HOST_NAME_NODE/d" /etc/hosts                                        配置主机名映射
echo "$HOST_IP $HOST_NAME" >> /etc/hosts
echo "$HOST_IP_NODE $HOST_NAME_NODE" >> /etc/hosts
printf "\033[35mPlease Reboot or Reconnect the terminal\n\033[0m"
bash 