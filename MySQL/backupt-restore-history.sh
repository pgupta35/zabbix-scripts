
# agenda:
# migrate CentOS 7 default (latest) MySQL 5.5 to MariaDB 12.3
#
# features:
# create daily partitioning from 2018-01-01 to this day for tables: history_log, history_str, history_text, history_uint, history
# enable automaticall partitioning in future for these 5 tables by using native MariaDB procedures listed
# https://zabbix.org/wiki/Docs/howto/mysql_partitioning
# https://zabbix.org/wiki/Docs/howto/mysql_partition <== this is the wrong one

# workflow:
# * stop zabbix-server, zabbix-agent. disable services at startup
# * backup everything except tables: history, history_uint, history_text, history_str, history_log
# * backup all 5 biggest tables separately 
# * remove MySQL 5.5, yum remove mariadb mariadb-server, rm -rf /etc/my.cnf, rm -rf /var/lib/mysql
# * clean yum cache, yum clean all, rm -rf /var/cache/yum
# * install MariaDB repo, https://downloads.mariadb.org/mariadb/repositories/#mirror=nluug&distro=CentOS&distro_release=centos7-amd64--centos7&version=10.3
# * install MariaDB server, yum install MariaDB-server MariaDB-client
# * restore zabbix database which contains no historical date. do not start zabbix-server
# * create table structure for all 5 tables
# * manually create partitions in the past period
# * create automatic partitioning in the future. do I need to recrate if already created?
# * restore all historical data, bzcat dbdump.bz2 | sudo mysql -uzabbix -p zabbix
# * tune MariaDB config

systemctl stop {zabbix-server,zabbix-agent}
systemctl status {zabbix-server,zabbix-agent}
systemctl disable {zabbix-server,zabbix-agent}

#backup zabbix all tables execpt the 5 biggest tables
yum install bzip2 -y
time=$(date +%Y%m%d%H%M)
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --create-options --ignore-table=zabbix.history_log --ignore-table=zabbix.history_str --ignore-table=zabbix.history_text --ignore-table=zabbix.history_uint --ignore-table=zabbix.history zabbix | bzip2 -9 > /root/$time.bz2
cd /root
echo uploading file..
./uploader.py uploader.cfg /root/$time.bz2

# backup only tables: 
# history_log
# history_str
# history_text
# history_uint
# history

time=$(date +%Y%m%d%H%M)
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --no-create-db --no-create-info zabbix history_log | bzip2 -9 > /root/history_log.$time.bz2
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --no-create-db --no-create-info zabbix history_str | bzip2 -9 > /root/history_str.$time.bz2
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --no-create-db --no-create-info zabbix history_text | bzip2 -9 > /root/history_text.$time.bz2
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --no-create-db --no-create-info zabbix history_uint | bzip2 -9 > /root/history_uint.$time.bz2
sudo mysqldump -uroot -p5sRj4GXspvDKsBXW --flush-logs --single-transaction --no-create-db --no-create-info zabbix history | bzip2 -9 > /root/history.$time.bz2
ls -lah /root/history*
./uploader.py uploader.cfg /root/history_log.$time.bz2
./uploader.py uploader.cfg /root/history_str.$time.bz2
./uploader.py uploader.cfg /root/history_text.$time.bz2
./uploader.py uploader.cfg /root/history_uint.$time.bz2
./uploader.py uploader.cfg /root/history.$time.bz2



yum remove mariadb mariadb-server
rm -rf /var/lib/mysql
mv /etc/my.cnf ~


#create MariaDB repo
#https://downloads.mariadb.org/mariadb/repositories/#mirror=nluug&distro=CentOS&distro_release=centos7-amd64--centos7&version=10.3

cat > /etc/yum.repos.d/MariaDB.repo << EOF
# MariaDB 10.3 CentOS repository list - created 2018-05-31 08:48 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1

EOF

yum clean all
rm -rf /var/cache/yum

yum -y install MariaDB-server MariaDB-client

systemctl start mariadb
systemctl status mariadb
systemctl enable mariadb

#mysql_secure_installation
/usr/bin/mysqladmin -u root password '5sRj4GXspvDKsBXW'

mysql -uroot -p'5sRj4GXspvDKsBXW'

#create zabbix database
mysql -h localhost -uroot -p5sRj4GXspvDKsBXW -P 3306 -s <<< 'create database zabbix character set utf8 collate utf8_bin;'

#create user 'zabbix' and allow user to connect to the database only from localhost
mysql -h localhost -uroot -p5sRj4GXspvDKsBXW -P 3306 -s <<< 'grant all privileges on zabbix.* to zabbix@localhost identified by "TaL2gPU5U9FcCU2u";'

mysql -h localhost -uroot -p5sRj4GXspvDKsBXW -P 3306 -s <<< 'show databases;' | grep zabbix


bzcat /root/$time.bz2 | sudo mysql -uzabbix -p zabbix

#create empty tables
mysql -u$(grep "^DBUser" /etc/zabbix/zabbix_server.conf|sed "s/^.*=//") -p$(grep "^DBPassword" /etc/zabbix/zabbix_server.conf|sed "s/^.*=//")

use zabbix;

CREATE TABLE `history_str` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` varchar(255) COLLATE utf8_bin NOT NULL DEFAULT '',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_str_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

CREATE TABLE `history_log` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `timestamp` int(11) NOT NULL DEFAULT '0',
  `source` varchar(64) COLLATE utf8_bin NOT NULL DEFAULT '',
  `severity` int(11) NOT NULL DEFAULT '0',
  `value` text COLLATE utf8_bin NOT NULL,
  `logeventid` int(11) NOT NULL DEFAULT '0',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_log_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

CREATE TABLE `history_uint` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` bigint(20) unsigned NOT NULL DEFAULT '0',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_uint_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

CREATE TABLE `history` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` double(16,4) NOT NULL DEFAULT '0.0000',
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

CREATE TABLE `history_text` (
  `itemid` bigint(20) unsigned NOT NULL,
  `clock` int(11) NOT NULL DEFAULT '0',
  `value` text COLLATE utf8_bin NOT NULL,
  `ns` int(11) NOT NULL DEFAULT '0',
  KEY `history_text_1` (`itemid`,`clock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

#now we can start zabbix-server


ALTER TABLE `history` PARTITION BY RANGE(clock)
(
PARTITION p2018___OLD VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-01 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_01 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-02 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_02 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-03 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_03 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-04 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_04 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-05 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_05 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-06 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_06 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-07 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_07 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-08 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_08 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-09 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_09 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-10 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_10 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-11 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_11 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-12 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_12 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-13 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_13 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-14 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_14 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-15 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_15 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-16 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_16 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-17 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_17 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-18 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_18 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-19 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_19 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-20 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_20 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-21 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_21 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-22 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_22 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-23 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_23 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-24 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_24 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-25 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_25 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-26 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_26 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-27 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_27 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-28 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_28 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-29 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_29 VALUES LESS THAN (UNIX_TIMESTAMP("2018-04-30 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_04_30 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-01 00:00:00")) ENGINE=InnoDB,

PARTITION p2018_05_01 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-02 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_02 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-03 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_03 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-04 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_04 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-05 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_05 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-06 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_06 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-07 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_07 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-08 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_08 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-09 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_09 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-10 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_10 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-11 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_11 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-12 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_12 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-13 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_13 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-14 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_14 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-15 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_15 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-16 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_16 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-17 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_17 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-18 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_18 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-19 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_19 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-20 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_20 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-21 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_21 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-22 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_22 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-23 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_23 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-24 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_24 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-25 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_25 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-26 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_26 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-27 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_27 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-28 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_28 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-29 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_29 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-30 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_30 VALUES LESS THAN (UNIX_TIMESTAMP("2018-05-31 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_05_31 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-01 00:00:00")) ENGINE=InnoDB,

PARTITION p2018_06_01 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-02 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_06_02 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-03 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_06_03 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-04 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_06_04 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-05 00:00:00")) ENGINE=InnoDB,
PARTITION p2018_06_05 VALUES LESS THAN (UNIX_TIMESTAMP("2018-06-06 00:00:00")) ENGINE=InnoDB
);

show create table history;

systemctl enable {zabbix-server,zabbix-agent}
systemctl start {zabbix-server,zabbix-agent}

