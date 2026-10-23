<?php
declare(strict_types=1);
namespace App\Controllers;

use App\Core\{Auth, Csrf, View};

final class AuthController
{
    public function showLogin(): void
    {
        if (Auth::check()) redirect('dashboard');
        View::render('login', ['title' => 'Sign in'], 'layout');
        unset($_SESSION['_old']);
    }

    public function login(): void
    {
        Csrf::verify();

        // very simple throttle: 5 fails -> wait 60s
        $_SESSION['_fails'] = $_SESSION['_fails'] ?? ['n' => 0, 't' => 0];
        if ($_SESSION['_fails']['n'] >= 5 && time() - $_SESSION['_fails']['t'] < 60) {
            flash('error', 'Too many attempts. Wait a minute and try again.');
            redirect('login');
        }

        $email = trim((string)($_POST['email'] ?? ''));
        $pass  = (string)($_POST['password'] ?? '');
        $_SESSION['_old'] = ['email' => $email];

        try {
            $ok = Auth::attempt($email, $pass);
        } catch (\Throwable $e) {
            flash('error', config('debug') ? 'Database error: ' . $e->getMessage() : 'System error. Contact support.');
            redirect('login');
        }

        if ($ok) {
            $_SESSION['_fails'] = ['n' => 0, 't' => 0];
            unset($_SESSION['_old']);
            redirect('dashboard');
        }

        $_SESSION['_fails']['n']++;
        $_SESSION['_fails']['t'] = time();
        flash('error', 'Wrong email or password.');
        redirect('login');
    }

    public function logout(): void
    {
        Csrf::verify();
        Auth::logout();
        session_start();
        flash('success', 'You have been signed out.');
        redirect('login');
    }
}
