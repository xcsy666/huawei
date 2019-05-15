#!/bin/bash  
  
HOSTNAME="localhost"                                           #数据库Server信息  
PORT="3306"  
USERNAME="xiandian"  
PASSWORD="000000"  
  
DBNAME=$1                                              #要创建的数据库的库名称  
#DBNAME="db_mariadb"                                              #要创建的数据库的库名称  
TABLENAME="table_mariadb"                                  #要创建的数据库的表的名称  
  
MYSQL_CMD="mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD}"  
echo ${MYSQL_CMD}  
  
echo "drop database ${DBNAME}"  
create_db_sql="drop database IF EXISTS ${DBNAME}"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库                     
if [ $? -ne 0 ]                                                                                #判断是否创建成功  
then  
 echo "drop databases ${DBNAME} failed ..."  
 exit 1  
fi  
  
echo "create database ${DBNAME}"  
create_db_sql="create database IF NOT EXISTS ${DBNAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库                     
if [ $? -ne 0 ]                                                                                #判断是否创建成功  
then  
 echo "create databases ${DBNAME} failed ..."  
 exit 1  
fi  
  
echo "create user ${DBNAME}"  
create_db_sql="grant all privileges on ${DBNAME}.* to ${DBNAME}@'%'  identified by 'yourpassword'"  
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库                     
if [ $? -ne 0 ]                                                                                #判断是否创建成功  
then  
 echo "create user ${DBNAME} failed ..."  
 exit 1  
fi  
  
#echo "create table ${TABLENAME}"  
#create_table_sql="create table ${TABLENAME}(  
#name char(6) NOT NULL,  
#id int default 0  
#)ENGINE=MyISAM DEFAULT CHARSET=latin1"  
#echo ${create_table_sql} | ${MYSQL_CMD} ${DBNAME}              #在给定的DB上，创建表  
#if [ $? -ne 0 ]                                                                                                #判断是否创建成功  
#then  
# echo "create  table ${DBNAME}.${TABLENAME}  fail ..."  
#fi  