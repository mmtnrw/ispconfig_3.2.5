<?php
require_once '../lib/config.inc.php';

$DBH = new PDO("mysql:host=".$conf['db_host'].";dbname=".$conf['db_database'], $conf['db_user'], $conf['db_password']);
$STH = $DBH->query('SELECT domain FROM web_domain;');


$STH->setFetchMode(PDO::FETCH_ASSOC);
while($row = $STH->fetch()) {
    if( $_REQUEST['domain'] == $row['domain'] )
    {
        http_response_code(200);
        die();
    }
}
http_response_code(404);
die();
?>
