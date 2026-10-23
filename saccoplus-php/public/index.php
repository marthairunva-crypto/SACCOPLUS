<?php
declare(strict_types=1);

require dirname(__DIR__) . '/app/bootstrap.php';

use App\Core\Router;
use App\Controllers\{HomeController, AuthController, DashboardController, MembersController, TellerController, LoansController};

$router = new Router();

// Clean URLs: no .php anywhere. "/" and "/index" both open the index page.
$router->get('index',           [HomeController::class, 'index']);
$router->get('login',           [AuthController::class, 'showLogin']);
$router->post('login',          [AuthController::class, 'login']);
$router->post('logout',         [AuthController::class, 'logout']);
$router->get('dashboard',       [DashboardController::class, 'index']);

// Members
$router->get('members',         [MembersController::class, 'index']);
$router->get('members/view',    [MembersController::class, 'view']);
$router->get('members/search',  [MembersController::class, 'search']);

// Teller Operations
$router->get('teller',          [TellerController::class, 'index']);
$router->get('teller/deposit',  [TellerController::class, 'showDeposit']);
$router->post('teller/deposit', [TellerController::class, 'deposit']);
$router->get('teller/withdraw', [TellerController::class, 'showWithdraw']);
$router->post('teller/withdraw',[TellerController::class, 'withdraw']);

// Loans
$router->get('loans',                [LoansController::class, 'index']);
$router->get('loans/create',         [LoansController::class, 'create']);
$router->post('loans/store',         [LoansController::class, 'store']);
$router->get('loans/view',           [LoansController::class, 'view']);
$router->post('loans/approve',       [LoansController::class, 'approve']);
$router->post('loans/reject',        [LoansController::class, 'reject']);
$router->post('loans/disburse',      [LoansController::class, 'disburse']);
$router->get('loans/repay',          [LoansController::class, 'repayForm']);
$router->post('loans/repay',         [LoansController::class, 'repay']);
$router->post('loans/add-charge',    [LoansController::class, 'addCharge']);
$router->get('loans/correct',        [LoansController::class, 'correctData']);
$router->post('loans/store-correction', [LoansController::class, 'storeCorrection']);

$router->dispatch();
