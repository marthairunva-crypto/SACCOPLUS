<?php
declare(strict_types=1);
namespace App\Core;

final class Router
{
    private array $routes = [];

    public function get(string $path, callable|array $handler): void  { $this->routes['GET'][$this->norm($path)]  = $handler; }
    public function post(string $path, callable|array $handler): void { $this->routes['POST'][$this->norm($path)] = $handler; }

    private function norm(string $p): string
    {
        $p = strtolower(trim($p, '/'));
        $p = preg_replace('/\.php$/', '', $p);   // safety: index.php -> index
        return $p === '' ? 'index' : $p;         // "/" and "/index" are the same page
    }

    public function dispatch(): void
    {
        $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        $uri    = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $base   = base_path();
        if ($base !== '' && strpos($uri, $base) === 0) $uri = substr($uri, strlen($base));
        $path = $this->norm(rawurldecode($uri));

        $handler = $this->routes[$method][$path] ?? null;
        if ($handler === null) {
            http_response_code(404);
            View::render('404', ['title' => 'Page not found']);
            return;
        }
        if (is_array($handler)) {
            [$class, $action] = $handler;
            (new $class())->$action();
        } else {
            $handler();
        }
    }
}
