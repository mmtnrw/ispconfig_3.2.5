# ispconfig - latest
Debian Testing, Apache, PHP, MySQL, PureFTPD, BIND, Postfix, Dovecot, Roundcube and ISPConfig 3.2.5

Changed a lot of Things since forking from wspimental, since noone was able to restart the container

Testing this Time:
- Install of RSPAMD
- Setting up Mail -> exporting to MailCow Container.......

Fixed:
- On Restart of Container the System Users were reincluded so that Apache can start.....
- When using external MySQL - ISPConfig is allowed to login only localhost not external.....

Features:
- You're able to use an external MySQL Database
- Setting of Admin Password within Docker
- Setting of MySql Host, Port and Password
- PHPMyAdmin
