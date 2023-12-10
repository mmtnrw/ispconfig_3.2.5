<?php
require_once '../lib/config.inc.php';

        define('DEBUG', true);
        error_reporting(E_ALL);
        error_reporting(-1);
        ini_set('error_reporting', E_ALL);
        ini_set('display_errors', '1');


$DBH = new PDO("mysql:host=".$conf['db_host'].";dbname=".$conf['db_database'], $conf['db_user'], $conf['db_password']);
$STH = $DBH->query('SELECT domain, subdomain FROM web_domain;');


$STH->setFetchMode(PDO::FETCH_ASSOC);
while($row = $STH->fetch()) {
    if( $_REQUEST['domain'] == $row['domain'] or $_REQUEST['domain'] == "www." . $row['domain'] )
    {
        http_response_code(200);
        die();
    }
}
http_response_code(404);
die();
?>
