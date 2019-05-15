FROM 10.0.3.138:5000/centos:latest
MAINTAINER Xiandian
RUN rm -fv /etc/yum.repos.d/*
ADD local.repo /etc/yum.repos.d/
ADD yum.tar /opt/
RUN yum clean all
RUN yum install -y java unzip
ENV LC_ALL en_US.UTF-8
ADD apache-tomcat-7.0.56.zip  /root/apache-tomcat-7.0.56.zip
RUN unzip /root/apache-tomcat-7.0.56.zip -d /root/
EXPOSE 8081
RUN chmod u+x /root/apache-tomcat-7.0.56/bin/*
ADD jenkins.war /root/apache-tomcat-7.0.56/webapps/ROOT.war
ENV CATALINA_HOME /root/apache-tomcat-7.0.56
CMD ${CATALINA_HOME}/bin/catalina.sh run

