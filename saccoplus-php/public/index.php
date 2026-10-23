<?php
declare(strict_types=1);

require dirname(__DIR__) . '/app/bootstrap.php';

use App\Core\Router;
use App\Controllers\{HomeController, AuthController, DashboardController};

$router = new Router();

// Clean URLs: no .php anywhere. "/" and "/index" both open the index page.
$router->get('index',     [HomeController::class, 'index']);
$router->get('login',     [AuthController::class, 'showLogin']);
$router->post('login',    [AuthController::class, 'login']);
$router->post('logout',   [AuthController::class, 'logout']);
$router->get('dashboard', [DashboardController::class, 'index']);

$router->dispatch();
