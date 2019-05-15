#!/bin/bash  
  
HOSTNAME="localhost"                                           #���ݿ�Server��Ϣ  
PORT="3306"  
USERNAME="xiandian"  
PASSWORD="000000"  
  
DBNAME=$1                                              #Ҫ���������ݿ�Ŀ�����  
#DBNAME="db_mariadb"                                              #Ҫ���������ݿ�Ŀ�����  
TABLENAME="table_mariadb"                                  #Ҫ���������ݿ�ı������  
  
MYSQL_CMD="mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD}"  
echo ${MYSQL_CMD}  
  
echo "drop database ${DBNAME}"  
create_db_sql="drop database IF EXISTS ${DBNAME}"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #�������ݿ�                     
if [ $? -ne 0 ]                                                                                #�ж��Ƿ񴴽��ɹ�  
then  
 echo "drop databases ${DBNAME} failed ..."  
 exit 1  
fi  
  
echo "create database ${DBNAME}"  
create_db_sql="create database IF NOT EXISTS ${DBNAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #�������ݿ�                     
if [ $? -ne 0 ]                                                                                #�ж��Ƿ񴴽��ɹ�  
then  
 echo "create databases ${DBNAME} failed ..."  
 exit 1  
fi  
  
echo "create user ${DBNAME}"  
create_db_sql="grant all privileges on ${DBNAME}.* to ${DBNAME}@'%'  identified by 'yourpassword'"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #�������ݿ�                     
if [ $? -ne 0 ]                                                                                #�ж��Ƿ񴴽��ɹ�  
then  
 echo "create user ${DBNAME} failed ..."  
 exit 1  
fi  
  
#echo "create table ${TABLENAME}"  
#create_table_sql="create table ${TABLENAME}(  
#name char(6) NOT NULL,  
#id int default 0  
#)ENGINE=MyISAM DEFAULT CHARSET=latin1"  
#echo ${create_table_sql} | ${MYSQL_CMD} ${DBNAME}              #�ڸ�����DB�ϣ�������  
#if [ $? -ne 0 ]                                                                                                #�ж��Ƿ񴴽��ɹ�  
#then  
# echo "create  table ${DBNAME}.${TABLENAME}  fail ..."  
#fi  