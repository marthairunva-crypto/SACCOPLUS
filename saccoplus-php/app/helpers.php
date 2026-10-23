<?php
declare(strict_types=1);

/** Base path if the app lives in a subfolder (e.g. /saccoplus/public). Empty at domain root. */
function base_path(): string {
    $dir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    return rtrim($dir === '/' ? '' : $dir, '/');
}

/** Clean URL builder: url('login') -> /login   (never adds .php) */
function url(string $path = ''): string {
    return base_path() . '/' . ltrim($path, '/');
}

function asset(string $path): string {
    return base_path() . '/assets/' . ltrim($path, '/');
}

function e(?string $v): string {
    return htmlspecialchars((string)$v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function redirect(string $path): never {
    header('Location: ' . url($path));
    exit;
}

function config(string $key, $default = null) {
    $v = $GLOBALS['config'];
    foreach (explode('.', $key) as $k) {
        if (!is_array($v) || !array_key_exists($k, $v)) return $default;
        $v = $v[$k];
    }
    return $v;
}

function flash(?string $key = null, ?string $message = null) {
    if ($message !== null) { $_SESSION['_flash'][$key] = $message; return null; }
    if ($key !== null) { $m = $_SESSION['_flash'][$key] ?? null; unset($_SESSION['_flash'][$key]); return $m; }
    return null;
}

function old(string $key): string { return e($_SESSION['_old'][$key] ?? ''); }
