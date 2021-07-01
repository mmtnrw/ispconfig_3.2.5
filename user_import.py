#!/bin/python3
import mysql.connector
import os

min_groupid=5004
min_userid=5003

mydb = mysql.connector.connect(
  host=os.environ.get('ISPC_MYSQL_HOST'),
  user="root",
  password=os.environ.get('ISPC_MYSQL_PASS'),
  database="dbispconfig"
)

mycursor = mydb.cursor(dictionary=True)

mycursor.execute("SELECT * FROM sys_group")

myresult = mycursor.fetchall()

for x in myresult:
  os.system('groupadd -g {} client{}'.format(min_groupid + x["groupid"],  x["groupid"] -1 ) )
  dbcursor = mydb.cursor(dictionary=True)
  dbcursor.execute( "SELECT * FROM web_domain WHERE sys_groupid = {}".format( x["groupid"] ) )
  r_domain = dbcursor.fetchall()
  for domain in r_domain:
    os.system( 'mkdir -p /var/log/ispconfig/httpd/{} && useradd -d {} -g {} -u {} -s /bin/false {}'.format(domain["domain"],domain['document_root'], min_groupid +x["groupid"],min_userid + domain["domain_id"],domain["system_user"] ) )
