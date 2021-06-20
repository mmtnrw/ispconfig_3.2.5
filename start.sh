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
if [ ! -z "$ISPC_MYSQL_HOST" ]; then
	sed -i "s/^mysql_hostname=localhost$/mysql_hostname=$ISPC_MYSQL_HOST/g" /root/ispconfig3_install/install/autoinstall.ini
fi
if [ ! -z "$ISPC_MYSQL_PASS" ]; then
	sed -i "s/^mysql_root_password=pass$/mysql_root_password=$ISPC_MYSQL_PASS/g" /root/ispconfig3_install/install/autoinstall.ini
fi


if [ ! -f /usr/local/ispconfig/interface/lib/config.inc.php ]; then
#	mysql_install_db
#	service mysql start \
#	&& echo "UPDATE mysql.user SET Password = PASSWORD('pass') WHERE User = 'root';" | mysql -u root \
#	&& echo "UPDATE mysql.user SET plugin='mysql_native_password' where user='root';" | mysql -u root \
#	&& echo "DELETE FROM mysql.user WHERE User='';" | mysql -u root \
#	&& echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql -u root \
#	&& echo "DROP DATABASE IF EXISTS test;" | mysql -u root \
#	&& echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" | mysql -u root \
#	&& echo "FLUSH PRIVILEGES;" | mysql -u root
	# RUN mysqladmin -u root password pass
	php -q /root/ispconfig3_install/install/install.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
	mkdir -p /var/www/html
	echo "" > /var/www/html/index.html
	rm -r /root/ispconfig3_install
else
	php -q /root/ispconfig3_install/install/update.php --autoinstall=/root/ispconfig3_install/install/autoinstall.ini
fi

if [ ! -z "$ISPC_PASSWORD" ]; then
	echo "USE dbispconfig;UPDATE sys_user SET passwort = md5('$ISPC_PASSWORD') WHERE username = 'admin';" | mysql -h $ISPC_MYSQL_HOST -u root -p$ISPC_MYSQL_PASS
fi


#service mysql start && php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini

screenfetch

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
