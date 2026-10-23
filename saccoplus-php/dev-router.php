<?php
// Local dev only (php -S). Mimics .htaccess: static files served, .php stripped, rest -> front controller.
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (preg_match('/\.php$/', $path)) { header('Location: ' . substr($path, 0, -4), true, 301); exit; }
if ($path !== '/' && is_file(__DIR__ . '/public' . $path)) return false;
chdir(__DIR__ . '/public');
$_SERVER['SCRIPT_NAME'] = '/index.php';
require __DIR__ . '/public/index.php';
