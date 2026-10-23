<?php
declare(strict_types=1);
namespace App\Core;

final class View
{
    /** Render a view inside the main layout. $layout=false for bare pages. */
    public static function render(string $view, array $data = [], string|false $layout = 'layout'): void
    {
        extract($data, EXTR_SKIP);
        ob_start();
        require ROOT_PATH . "/app/Views/{$view}.php";
        $content = ob_get_clean();

        if ($layout === false) { echo $content; return; }
        require ROOT_PATH . "/app/Views/{$layout}.php";
    }
}
