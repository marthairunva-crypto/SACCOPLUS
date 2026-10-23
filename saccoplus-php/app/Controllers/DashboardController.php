<?php
declare(strict_types=1);
namespace App\Controllers;

use App\Core\{Auth, View};

final class DashboardController
{
    public function index(): void
    {
        Auth::require();
        View::render('dashboard', ['title' => 'Dashboard', 'user' => Auth::user()]);
    }
}
