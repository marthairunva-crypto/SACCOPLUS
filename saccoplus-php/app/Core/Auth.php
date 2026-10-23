<?php
declare(strict_types=1);
namespace App\Core;

final class Auth
{
    public static function check(): bool { return !empty($_SESSION['user']); }
    public static function user(): ?array { return $_SESSION['user'] ?? null; }

    public static function attempt(string $email, string $password): bool
    {
        $st = DB::pdo()->prepare('SELECT * FROM users WHERE email = ? AND status = "active" LIMIT 1');
        $st->execute([$email]);
        $u = $st->fetch();

        // Same work whether or not the user exists (timing safety)
        $hash = $u['password_hash'] ?? password_hash('dummy', PASSWORD_DEFAULT);
        $ok = password_verify($password, $hash) && $u;
        if (!$ok) return false;

        session_regenerate_id(true);
        $_SESSION['user'] = [
            'id' => (int)$u['id'], 
            'sacco_id' => $u['sacco_id'] ? (int)$u['sacco_id'] : null,
            'branch_id' => $u['branch_id'] ? (int)$u['branch_id'] : null,
            'name' => $u['name'], 
            'email' => $u['email'], 
            'role' => $u['role'],
        ];
        DB::pdo()->prepare('UPDATE users SET last_login_at = NOW() WHERE id = ?')->execute([$u['id']]);
        return true;
    }

    public static function require(): void
    {
        if (!self::check()) redirect('login');
    }

    public static function logout(): void
    {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $p = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
        }
        session_destroy();
    }
}
