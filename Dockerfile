FROM debian:buster-slim

# --- 1 Inciando 
RUN apt-get -y update && apt-get -y upgrade
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install man rsyslog rsyslog-relp logrotate supervisor screenfetch nano apt-utils

# --- 2 Instalando o SSH server
#RUN apt-get -y install ssh openssh-server rsync
RUN apt-get -qq update && apt-get -y -qq install ssh openssh-server rsync && \
    mkdir /root/.ssh && touch /root/.ssh/authorized_keys
RUN sed -i 's/^#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config

# --- 3 Alterar o shell padrão
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN mkdir -p /usr/share/man/man1
RUN dpkg-reconfigure --force dash

# --- 5 Synchronize the System Clock
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get -y install ntp ntpdate

# --- 6 Removendo sendmail
#RUN service sendmail stop; update-rc.d -f sendmail remove
RUN echo -n "Removing Sendmail... "
#&& service sendmail stop hide_output update-rc.d -f sendmail remove apt_remove sendmail

# --- 7 Install Postfix, Dovecot, MySQL, phpMyAdmin, rkhunter, binutils
RUN echo "mariadb-server  mariadb-server/root_password_again password pass" | debconf-set-selections
RUN echo "mariadb-server  mariadb-server/root_password password pass" | debconf-set-selections
RUN echo "mariadb-server-10.0 mysql-server/root_password password pass" | debconf-set-selections
RUN echo "mariadb-server-10.0 mysql-server/root_password_again password pass" | debconf-set-selections
RUN echo -n "Installing SMTP Mail server (Postfix)... " \
&& echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections \
&& echo "postfix postfix/mailname string mail.mmt.nrw" | debconf-set-selections
RUN apt-get -y install postfix postfix-mysql postfix-doc mariadb-client mariadb-server openssl getmail4 rkhunter binutils dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd sudo curl
ADD ./etc/postfix/master.cf /etc/postfix/master.cf
RUN mv /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
ADD ./etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
# RUN apt-get -y install expect
RUN mv /etc/mysql/debian.cnf /etc/mysql/debian.cnf.backup
ADD ./etc/mysql/debian.cnf /etc/mysql/debian.cnf
ADD ./etc/security/limits.conf /etc/security/limits.conf
RUN mkdir -p /etc/systemd/system/mysql.service.d/
ADD ./etc/systemd/system/mysql.service.d/limits.conf /etc/systemd/system/mysql.service.d/limits.conf

# --- 9 Install Amavisd-new, SpamAssassin And Clamav
RUN apt-get -y install amavisd-new spamassassin clamav clamav-daemon unzip bzip2 arj nomarch lzop cabextract p7zip p7zip-full lrzip apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl libdbd-mysql-perl postgrey
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf
RUN service spamassassin stop && systemctl disable spamassassin
RUN update-rc.d -f spamassassin remove

# -- 10 Install XMPP Server
RUN apt-get -qq update && apt-get -y -qq install git lua5.1 liblua5.1-0-dev lua-filesystem libidn11-dev libssl-dev lua-zlib lua-expat lua-event lua-bitop lua-socket lua-sec luarocks luarocks
RUN luarocks install lpc
RUN adduser --no-create-home --disabled-login --gecos 'Metronome' metronome
RUN cd /opt && git clone https://github.com/maranda/metronome.git metronome
RUN cd /opt/metronome && ./configure --ostype=debian --prefix=/usr && make && make install

RUN echo $(grep $(hostname) /etc/hosts | cut -f1) localhost >> /etc/hosts
RUN apt-get -y install apache2 apache2-doc apache2-utils libapache2-mod-php php7.3 php7.3-common php7.3-gd php7.3-mysql php7.3-imap php7.3-cli php7.3-cgi libapache2-mod-fcgid apache2-suexec-pristine php-pear mcrypt  imagemagick libruby libapache2-mod-python php7.3-curl php7.3-intl php7.3-pspell php7.3-recode php7.3-sqlite3 php7.3-tidy php7.3-xmlrpc php7.3-xsl memcached php-memcache php-imagick php-gettext php7.3-zip php7.3-mbstring memcached libapache2-mod-passenger php7.3-soap php7.3-fpm php7.3-opcache php-apcu libapache2-reload-perl
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf && a2enconf servername
ADD ./etc/apache2/conf-available/httpoxy.conf /etc/apache2/conf-available/httpoxy.conf
RUN a2enmod suexec rewrite ssl actions include dav_fs dav auth_digest cgi headers actions proxy_fcgi alias 
RUN a2enconf httpoxy
# --- 15 Install Let's Encrypt
#RUN apt-get -y install certbot
#RUN apt-get -y install python-certbot-apache -t jessie-backports
RUN apt-get -y install python3-certbot-apache

# ---  phpMyAdmin
RUN mkdir -p /var/www/html/phpmyadmin
RUN mkdir -p /tmp/myadmin && cd /tmp/myadmin
RUN wget -P Downloads https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
RUN cd Downloads && tar xvf phpMyAdmin-latest-all-languages.tar.gz --strip-components=1 -C /var/www/html/phpmyadmin
RUN cp /var/www/html/phpmyadmin/config.sample.inc.php /var/www/html/phpmyadmin/config.inc.php
ADD ./etc/apache2/conf-available/phpmyadmin.conf /etc/apache2/conf-available/phpmyadmin.conf
RUN a2enmod phpmyadmin


# --- 16 Install Mailman
RUN echo 'mailman mailman/default_server_language select en' | debconf-set-selections
RUN apt-get -y install mailman
ADD ./etc/aliases /etc/aliases
RUN newaliases
RUN service postfix restart
RUN ln -s /etc/mailman/apache.conf /etc/apache2/conf-enabled/mailman.conf
RUN service apache2 restart

# --- 17 Install PureFTPd and Quota
# install package building helpers
RUN echo 'deb-src http://deb.debian.org/debian buster main' >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get -qq -y --force-yes install dpkg-dev debhelper openbsd-inetd debian-keyring
# install dependancies
RUN apt-get -y -qq build-dep pure-ftpd
# build from source
RUN mkdir /tmp/pure-ftpd-mysql/ && \
    cd /tmp/pure-ftpd-mysql/ && \
    apt-get -qq source pure-ftpd-mysql && \
    cd pure-ftpd-* && \
    sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules && \
    dpkg-buildpackage -b -uc > /tmp/pureftpd-build-stdout.txt 2> /tmp/pureftpd-build-stderr.txt
# install the new deb files
RUN dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-common*.deb && dpkg -i /tmp/pure-ftpd-mysql/pure-ftpd-mysql*.deb
# Prevent pure-ftpd upgrading
RUN apt-mark hold pure-ftpd-common pure-ftpd-mysql
# setup ftpgroup and ftpuser
RUN groupadd ftpgroup && useradd -g ftpgroup -d /dev/null -s /etc ftpuser
RUN apt-get -qq update && apt-get -y -qq install quota quotatool
RUN sed -i 's/VIRTUALCHROOT=false/VIRTUALCHROOT=true/g'  /etc/default/pure-ftpd-common
RUN sed -i 's/STANDALONE_OR_INETD=inetd/STANDALONE_OR_INETD=standalone/g'  /etc/default/pure-ftpd-common
RUN sed -i 's/UPLOADSCRIPT=/UPLOADSCRIPT=\/etc\/pure-ftpd\/clamav_check.sh/g'  /etc/default/pure-ftpd-common
RUN echo 1 > /etc/pure-ftpd/conf/TLS && mkdir -p /etc/ssl/private/
RUN echo "30000 31000" > /etc/pure-ftpd/conf/PassivePortRange


# --- 18 Install BIND DNS Server
RUN apt-get -y install bind9 dnsutils haveged
RUN systemctl enable haveged
#RUN systemctl start haveged

# --- 19 Install Vlogger, Webalizer, and AWStats
RUN apt-get -y install webalizer awstats geoip-database libclass-dbi-mysql-perl libtimedate-perl
ADD etc/cron.d/awstats /etc/cron.d/

# --- 20 Install Jailkit
RUN apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils python
RUN cd /tmp \
&& wget http://olivier.sessink.nl/jailkit/jailkit-2.22.tar.gz \
&& tar xvfz jailkit-2.22.tar.gz \
&& cd jailkit-2.22 \
&& echo 5 > debian/compat \
&& ./debian/rules binary \
&& cd /tmp \
&& rm -rf jailkit-2.22*

# --- 21 Install fail2ban
RUN apt-get -y install fail2ban
ADD ./etc/fail2ban/jail.local /etc/fail2ban/jail.local
ADD ./etc/fail2ban/filter.d/pureftpd.conf /etc/fail2ban/filter.d/pureftpd.conf
ADD ./etc/fail2ban/filter.d/dovecot-pop3imap.conf /etc/fail2ban/filter.d/dovecot-pop3imap.conf
RUN echo "ignoreregex =" >> /etc/fail2ban/filter.d/postfix-sasl.conf
#RUN service fail2ban restart

# --- 22 UFW firewall
RUN apt-get -y install ufw

# --- 23 Install RoundCube
RUN apt-get -y install roundcube roundcube-core roundcube-mysql roundcube-plugins
ADD ./etc/apache2/conf-enabled/roundcube.conf /etc/apache2/conf-enabled/roundcube.conf
ADD ./etc/roundcube/config.inc.php /etc/roundcube/config.inc.php
RUN service apache2 restart

# --- 24 Install ISPConfig 3
RUN cd /root \
&& wget -O ISPConfig-3.2.5.tar.gz https://ispconfig.org/downloads/ISPConfig-3.2.5.tar.gz \
&& tar xfz ISPConfig-3.2.5.tar.gz 
#\
#&& mv ispconfig3-stable-3.2* ispconfig3_install

## Install ISPConfig
ADD ./autoinstall.ini /root/ispconfig3_install/install/autoinstall.ini
#RUN service mysql restart && php -q /tmp/ispconfig3_install/install/install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
#RUN sed -i 's/^NameVirtualHost/#NameVirtualHost/g' /etc/apache2/sites-enabled/000-ispconfig.vhost && sed -i 's/^NameVirtualHost/#NameVirtualHost/g' /etc/apache2/sites-enabled/000-ispconfig.conf

ADD ./etc/postfix/master.cf /etc/postfix/master.cf
ADD ./etc/clamav/clamd.conf /etc/clamav/clamd.conf

RUN echo "export TERM=xterm" >> /root/.bashrc

EXPOSE 20/tcp 21/tcp 22/tcp 53 80/tcp 443/tcp 953/tcp 8080/tcp 30000-31000/tcp

# ISPCONFIG Initialization and Startup Script
ADD ./start.sh /start.sh
ADD ./supervisord.conf /etc/supervisor/supervisord.conf
ADD ./etc/cron.daily/sql_backup.sh /etc/cron.daily/sql_backup.sh
#ADD ./autoinstall.ini /tmp/ispconfig3_install/install/autoinstall.ini
RUN chmod 755 /start.sh
RUN mkdir -p /var/run/sshd
RUN mkdir -p /var/log/supervisor
RUN mv /bin/systemctl /bin/systemctloriginal
ADD ./bin/systemctl /bin/systemctl
RUN chmod +x /bin/systemctl
RUN mkdir -p /var/backup/sql

# User Import Mod
RUN apt-get install -y python3-pip && pip3 install mysql-connector
ADD ./user_import.py /user_import.py
RUN chmod 755 /user_import.py

# Persistence of Folders
RUN mv /etc/apache2 /etc/apache2.org

#RUN service mysql start \
#&& echo "FLUSH PRIVILEGES;" | mysql -u root

#Persistent Volume
RUN mkdir -p /usr/local/ispconfig
RUN sed -i "s/is_dir('\/usr\/local\/ispconfig/is_dir('\/usr\/local\/ispconfigi/g" /root/ispconfig3_install/install/install.php

#Wait for MySQL to come up...
RUN apt-get install -y netcat

RUN apt-get autoremove -y && apt-get clean && rm -rf /tmp/*

VOLUME ["/var/www/","/var/mail/","/var/backup/","/etc/letsencrypt", "/usr/local/ispconfig", "/etc/apache2", "/etc/php/7.3/fpm/pool.d", "/var/lib/mysql" ]

# Must use double quotes for json formatting.
CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisor/supervisord.conf"]

CMD ["/bin/bash", "/start.sh"]
