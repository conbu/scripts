#!/bin/bash
  
# @sacloud-once

# @sacloud-desc-begin
# zabbix server/agentのインストールおよび、apt-get update/upgrade/を実行します
# 完了後自動再起動します
# このスクリプトは、Ubuntuでのみ動作します
# このスクリプトのDBは、mysql5.7を想定しています
# このスクリプトのPHPは、7.0を想定しています
# @sacloud-desc-end
# @sacloud-require-archive distro-ubuntu


#---------START OF Pass/User,update/upgrade---------#
# @sacloud-text required maxlen=50 user_name "ホストOSのユーザ名"
# @sacloud-text required maxlen=50 user_pass "ホストOSのユーザのパスワード"
# @sacloud-text required maxlen=50 Host_Name "ホスト名(例:ホスト名)"
# @sacloud-text required maxlen=50 default="zabbix" db_name "DB名"
# @sacloud-text required maxlen=50 default="zabbix" db_pass "DBのパスワード"
# @sacloud-text required maxlen=50 mgmt_IP "managementセグメント側IPアドレス(例:10.200.0.14)"
# @sacloud-text required maxlen=50 mgmt_subnet "managementサブネットマスク(例:255.255.255.0)"
# @sacloud-text required maxlen=50 mgmt_gw "management default gateway(例:10.200.0.1)"
# @sacloud-text required maxlen=50 genti_net "wifi会場mgmtネットワークセグメント(例:10.200.10.0/16)"
# @sacloud-text required maxlen=50 ntp_server "ntpサーバのネットワークアドレス(例:10.200.0.16)"

#User
sudo useradd -p $(perl -e 'print crypt("@@@user_pass@@@", "\$6\$neconbu")') -m --skel /etc/skel -s /bin/bash @@@user_name@@@
sed -i "s%sudo:\(.*\)$%sudo:\1,@@@user_name@@@%g" /etc/group

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -y update || exit 1
sudo -E apt-get -y upgrade || exit 1
#---------END OF Pass/User,update/upgrade---------#

#---------START OF,Hosts,SSH,NTP---------#
#Hosts
cat <<BEOS>> /etc/hosts
@@@mgmt_IP@@@ @@@Host_Name@@@
BEOS
sed -i "s%^::1%#::1%" /etc/hosts
sed -i "s%^ff02::1%#ff02::1%" /etc/hosts
sed -i "s%^ff02::2%#ff02::2%" /etc/hosts


#SSH
cat <<CEOS>> /etc/hosts.allow
sshd : @@@mgmt_IP@@@/@@@mgmt_subnet@@@
CEOS

cat <<DEOS>> /etc/hosts.deny
sshd : all
DEOS

sed -i "s%^#ListenAddress 0.0.0.0%ListenAddress @@@mgmt_IP@@@%" /etc/ssh/sshd_config
sed -i "s%^PermitRootLogin prohibit-password%#PermitRootLogin prohibit-password%" /etc/ssh/sshd_config
sed -i "s%^#PasswordAuthentication yes%PasswordAuthentication yes%" /etc/ssh/sshd_config
sed -i "s%^UsePAM yes%UsePAM no%" /etc/ssh/sshd_config

cat <<EEOS>> /etc/ssh/sshd_config
PermitRootLogin no
EEOS


#NTP
sudo -E apt-get -y install ntp
sed -i "s%^pool ntp.ubuntu.com%#pool ntp.ubuntu.com%g" /etc/ntp.conf
sed -i "s%^server ntp1.sakura.ad.jp%server @@@ntp_server@@@%" /etc/ntp.conf
sed -i "s%^restrict -4 ntp1.sakura.ad.jp%restrict -4 @@@ntp_server@@@%" /etc/ntp.conf
#---------END OF User modfy,Hosts,SSH,NTP---------#


# -----------START OF Apache----------- #
sudo -E apt-get -y install apache2 || exit 1
sed -i "s%^ServerTokens OS%ServerTokens Prod%" /etc/apache2/conf-enabled/security.conf
systemctl enable apache2
# -----------END OF Apache----------- #


# -----------START OF PHP----------- #
#PHPのバージョン指定を何とかしたい
sudo -E apt-get -y install php php-cgi libapache2-mod-php php-common php-pear php-mbstring || exit 1
a2enconf php7.0-cgi
sed -i "s%^;date.timezone =%date.timezone = "Asia/Tokyo"%" /etc/php/7.0/apache2/php.ini
sed -i "s%^max_execution_time = 30%max_execution_time = 300%" /etc/php/7.0/apache2/php.ini
sed -i "s%^max_input_time = 60%max_input_time = 300%" /etc/php/7.0/apache2/php.ini
sed -i "s%^post_max_size = 8M%post_max_size = 16M%" /etc/php/7.0/apache2/php.ini
# -----------END OF PHP----------- #


# -----------START OF Firewall----------- #
ufw enable || exit 1
ufw default DENY || exit 1
ufw allow 22 || exit 1
ufw allow 53 || exit 1
ufw allow 80 || exit 1
ufw allow 123 || exit 1
ufw allow 161 || exit 1
ufw allow 162 || exit 1
ufw allow 443 || exit 1
ufw allow 10050 || exit 1
ufw allow 10051 || exit 1
systemctl enable ufw
# -----------END OF Firewall----------- #


# -----------START OF Network----------- #
# 各サーバのインターフェイスとアドレス設計に合わせて適宜修正が必要。
cat << EOS >> /etc/network/interfaces
auto eth1
iface eth1 inet static
address @@@mgmt_IP@@@
netmask @@@mgmt_subnet@@@
gateway @@@mgmt_gw@@@

up route add -net @@@genti_net@@@ gw @@@mgmt_gw@@@ dev eth1

EOS
# -----------END OF Network----------- #


#---------START OF DB---------#
#mysqlのバージョン指定をなんとかしたい
echo "mysql-server-5.7 mysql-server/root_password password" @@@db_pass@@@ | debconf-set-selections
echo "mysql-server-5.7 mysql-server/root_password_again password" @@@db_pass@@@ | debconf-set-selections
sudo -E apt-get -y install mysql-server-5.7
#---------END OF DB---------#


#---------START OF Zabbix---------#

### パラメータの設定
#my.cnfの設定
#一時的にパスワード認証を無しとしている
cat <<AEOS>> /etc/mysql/my.cnf
[mysqld]
character-set-server = utf8
collation-server     = utf8_bin
skip-character-set-client-handshake
innodb_file_per_table
innodb_buffer_pool_size=1024MB
innodb_log_file_size=128M
[mysql]
default-character-set = utf8
[client]
default-character-set=utf8
host=localhost
user=root
password=@@@db_pass@@@
AEOS

### DBとDBユーザの作成
mysql -uroot -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -uroot -e "grant all privileges on zabbix.* to zabbix@localhost identified by '@@@db_pass@@@';"
mysql -uroot -e "flush privileges;"

wget "http://repo.zabbix.com/zabbix/3.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.2-1+xenial_all.deb"
sudo dpkg -i zabbix-release_3.2-1+xenial_all.deb

sudo apt-get update
sudo -E apt-get -y install snmp || exit 1
sudo -E apt-get -y install zabbix-server-mysql zabbix-agent zabbix-frontend-php php-mysql php-gd php-xml-util php-mbstring php-bcmath php-net-socket php-gettext || exit 1

# DBテーブルの作成
cd /usr/share/doc/zabbix-server-mysql/
sudo zcat create.sql.gz | mysql -uroot @@@db_pass@@@
#cd /usr/share/zabbix-server-mysql/
#sudo zcat schema.sql.gz | mysql -uroot ${db_pass}
#sudo zcat images.sql.gz | mysql -uroot ${db_pass}
#sudo zcat data.sql.gz | mysql -uroot ${db_pass}

## Zabbixコンフィグ内DBユーザパスワード設定
sed -i -e "s%# DBPassword=%DBPassword=@@@db_pass@@@%" /etc/zabbix/zabbix_server.conf

systemctl start zabbix-server
systemctl enable zabbix-server
systemctl start zabbix-agent
systemctl enable zabbix-agent
systemctl restart apache2

##MIBsの設定
sudo -E apt-get -y install snmp-mibs-downloader
cat <<FEOS>> /etc/snmp/snmp.conf
mibdirs  /home/ubuntu/.snmp/mibs:/usr/share/snmp/mibs:/usr/share/snmp/mibs/iana:/usr/share/snmp/mibs/ietf:/usr/share/mibs/site:/usr/share/snmp/mibs:/usr/share/mibs/iana:/usr/share/mibs/ietf:/usr/share/mibs/netsnmp:/var/lib/mibs/iana:/var/lib/mibs/ietf
mibs +ALL
FEOS

#my.cnfの設定
#パスワード認証を有りに戻している
sed -i "s%^host=localhost%%" /etc/mysql/my.cnf
sed -i "s%^user=root%%" /etc/mysql/my.cnf
sed -i "s%^password=@@@db_pass@@@%%" /etc/mysql/my.cnf

#Zabbixの日本語対応
##グラフ
sudo -E apt-get -y install fonts-ipafont-gothic
sudo ln -s /usr/share/fonts/opentype/ipafont-gothic/ipag.ttf /usr/share/zabbix/fonts/graphfont.ttf
sudo sed -i "s%realpath('fonts')%'/usr/share/fonts/opentype/ipafont-gothic'%" /usr/share/zabbix/include/defines.inc.php
sudo sed -i "s%graphfont%ipag%" /usr/share/zabbix/include/defines.inc.php
#インターフェイス
sudo localedef -f UTF-8 -i ja_JP ja_JP
sudo service zabbix-server restart
sudo service apache2 restart

#---------END OF Zabbix---------#

sh -c 'sleep 10; reboot' &
exit 0
