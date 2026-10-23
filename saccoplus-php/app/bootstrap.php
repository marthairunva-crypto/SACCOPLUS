<?php
declare(strict_types=1);

define('ROOT_PATH', dirname(__DIR__));
$GLOBALS['config'] = require ROOT_PATH . '/config/config.php';

date_default_timezone_set($GLOBALS['config']['timezone']);

if ($GLOBALS['config']['debug']) {
    ini_set('display_errors', '1');
    error_reporting(E_ALL);
} else {
    ini_set('display_errors', '0');
}

// Tiny PSR-4 style autoloader: App\Core\Router -> app/Core/Router.php
spl_autoload_register(function (string $class): void {
    if (strpos($class, 'App\\') !== 0) return;
    $file = ROOT_PATH . '/app/' . str_replace('\\', '/', substr($class, 4)) . '.php';
    if (is_file($file)) require $file;
});

// Secure session
$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'secure'   => $https,
    'httponly' => true,
    'samesite' => 'Lax',
]);
session_name('saccoplus_sid');
session_start();

require ROOT_PATH . '/app/helpers.php';
