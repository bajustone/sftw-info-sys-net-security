<?php

# DVWA configuration (matches Web App Security Lab 5, Steps 5–6).
# Credentials: admin / password (default DVWA login)
# DB: dvwa / password on localhost via MariaDB
# Modeled on DVWA's shipped config.inc.php.dist — includes the MYSQL/SQLITE
# constants and SQLI_DB which DVWA requires.

$DBMS = 'MySQL';

$_DVWA = array();
$_DVWA[ 'db_server' ]   = '127.0.0.1';
$_DVWA[ 'db_database' ] = 'dvwa';
$_DVWA[ 'db_user' ]     = 'dvwa';
$_DVWA[ 'db_password' ] = 'password';
$_DVWA[ 'db_port' ]     = '3306';

$_DVWA[ 'recaptcha_public_key' ]  = '';
$_DVWA[ 'recaptcha_private_key' ] = '';

$_DVWA[ 'default_security_level' ] = 'low';
$_DVWA[ 'default_locale' ]         = 'en';
$_DVWA[ 'disable_authentication' ] = false;

define( 'MYSQL',  'mysql' );
define( 'SQLITE', 'sqlite' );

# SQL Injection / Blind SQLi lab backend (must be MYSQL or SQLITE)
$_DVWA[ 'SQLI_DB' ] = MYSQL;

?>
