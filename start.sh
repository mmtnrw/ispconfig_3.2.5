#!/bin/bash
# DOCKERPASS=$(openssl rand -base64 32)
# sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
if [ ! -z "$DEFAULT_EMAIL_HOST" ]; then
	sed -i "s/^\(DEFAULT_EMAIL_HOST\) = .*$/\1 = '$MAILMAN_EMAIL_HOST'/g" /etc/mailman/mm_cfg.py
	newlist -q mailman $(MAILMAN_EMAIL) $(MAILMAN_PASS)
	newaliases
fi
if [ ! -z "$ISPC_LANGUAGE" ]; then
	sed -i "s/^language=en$/language=$ISPC_LANGUAGE/g" /root/ispconfig3_install/install/autoinstall.ini
fi
if [ ! -z "$ISPC_COUNTRY" ]; then
	sed -i "s/^ssl_cert_country=AU$/ssl_cert_country=$ISPC_COUNTRY/g" /root/ispconfig3_install/install/autoinstall.ini
fi
if [ ! -z "$ISPC_HOSTNAME" ]; then
	sed -i "s/^hostname=server1.example.com$/hostname=$ISPC_HOSTNAME/g" /root/ispconfig3_install/install/autoinstall.ini
	sed -i "s/^ssl_cert_common_name=server1.example.com$/ssl_cert_common_name=$ISPC_HOSTNAME/g" /root/ispconfig3_install/install/autoinstall.ini
	sed -i "s/^ssl_cert_email=hostmaster@example.com$/ssl_cert_email=hostmaster@$ISPC_HOSTNAME/g" /root/ispconfig3_install/install/autoinstall.ini
fi

if [ -z "$ISPC_MYSQL_HOST" ]; then
	ISPC_MYSQL_HOST="localhost"
fi

sed -i "s/^mysql_hostname=localhost$/mysql_hostname=$ISPC_MYSQL_HOST/g" /root/ispconfig3_install/install/autoinstall.ini
sed -i "s/^\$cfg\['Servers'\]\[\$i\]\['host'\].*;/\$cfg['Servers'][\$i]['host'] = '$ISPC_MYSQL_HOST';\n/g" /usr/share/phpmyadmin/config.inc.php

if [ "$ISPC_MYSQL_HOST" = "localhost" ] && [ ! -f /usr/local/ispconfig/interface/lib/config.inc.php ]; then
	mkdir -p /var/lib/mysql
	mysql_install_db
	service mysql start
fi
while ! nc -z $ISPC_MYSQL_HOST 3306; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done


if [ ! -z "$ISPC_MYSQL_PASS" ]; then
	sed -i "s/^mysql_root_password=pass$/mysql_root_password=$ISPC_MYSQL_PASS/g" /root/ispconfig3_install/install/autoinstall.ini
else
	ISPC_MYSQL_PASS="pass"
fi



if [ ! -f /usr/local/ispconfig/interface/lib/config.inc.php ]; then
	
	if [ "$ISPC_MYSQL_HOST" = "localhost" ] ; then
		echo "UPDATE mysql.user SET Password = PASSWORD('$ISPC_MYSQL_PASS') WHERE User = 'root';" | mysql -u root \
		&& echo "UPDATE mysql.user SET plugin='mysql_native_password' where user='root';" | mysql -u root \
		&& echo "DELETE FROM mysql.user WHERE User='';" | mysql -u root \
		&& echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql -u root \
		&& echo "DROP DATABASE IF EXISTS test;" | mysql -u root \
		&& echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" | mysql -u root \
		&& echo "FLUSH PRIVILEGES;" | mysql -u root
	fi
	
#	echo "CREATE DATABASE phpmyadmin;" | mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
#	echo "CREATE USER 'pma'@'localhost' IDENTIFIED BY '$ISPC_PASSWORD';" | mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
#	echo "GRANT ALL PRIVILEGES ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '$ISPC_PASSWORD' WITH GRANT OPTION;" | mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
#	echo "FLUSH PRIVILEGES;" | mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST

#	mysql -u root -p$ISPC_MYSQL_PASS phpmyadmin < /usr/share/phpmyadmin/sql/create_tables.sql

	mkdir -p /etc/php/7.3/fpm/pool.d
	mkdir -p /etc/apache2
	cp -R /etc/apache2.org/* /etc/apache2
	mkdir -p /etc/bind
	cp -R /etc/bind.org/* /etc/bind
	mkdir -p /var/www/html
	echo "" > /var/www/html/index.html
	source /etc/apache2/envvars
	php -q /root/ispconfig3_install/install/install.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
	
	
#	rm -r /root/ispconfig3_install
else
	ln -s /usr/local/ispconfig/interface/ssl/ispserver.crt /etc/postfix/smtpd.cert
	ln -s /usr/local/ispconfig/interface/ssl/ispserver.key /etc/postfix/smtpd.key
	mkdir -p /var/lib/php7.3-fpm
	cd  /root/ispconfig3_install/install && php -q /root/ispconfig3_install/install/update.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
	python3 /user_import.py
fi

##### Database Fixing #####
if [ "$ISPC_MYSQL_HOST" != "localhost" ] ; then
	DB_PASS=`cat /usr/local/ispconfig/server/lib/config.inc.php|grep db_password|head -n1|cut -d "'" -f4`
	echo "GRANT USAGE ON *.* TO 'ispconfig'@'%' IDENTIFIED BY '$DB_PASS';"|mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
	echo "GRANT ALL PRIVILEGES ON dbispconfig.* TO 'ispconfig'@'%';"|mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
	echo "DROP USER IF EXISTS 'ispconfig'@'$ISPC_HOSTNAME';"|mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
	echo "FLUSH PRIVILEGES;"|mysql -u root -p$ISPC_MYSQL_PASS -h $ISPC_MYSQL_HOST
	service mysql stop
fi

if [ ! -z "$ISPC_PASSWORD" ]; then
	echo "USE dbispconfig;UPDATE sys_user SET passwort = md5('$ISPC_PASSWORD') WHERE username = 'admin';" | mysql -h $ISPC_MYSQL_HOST -u root -p$ISPC_MYSQL_PASS
#	sed -i "s/^\$cfg\['blowfish_secret'\] = ''/\$cfg['blowfish_secret'] = '$ISPC_PASSWORD'/g" /usr/share/phpmyadmin/config.inc.php
	chmod 660 /usr/share/phpmyadmin/config.inc.php
	chown www-data:www-data -R /usr/share/phpmyadmin
fi


#service mysql start && php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini

screenfetch

# Fixing that Apache Pids are overwritten
/etc/init.d/php7.3-fpm stop
/etc/init.d/apache2 stop
/etc/init.d/php7.3-fpm start

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# Create and install a script for Caddy wildcard TLS so that it can check if the domain exists
cp /check.php /usr/local/ispconfig/interface/web/check.php
chmod 777 /usr/local/ispconfig/interface/web/check.php
