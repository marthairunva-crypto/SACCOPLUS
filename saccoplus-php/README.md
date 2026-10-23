# SACCOPLUS v2 (core PHP + MySQL)

Parallel rebuild. The Flutter + Firestore app stays live and untouched.

## Run locally
1. `mysql -u root -p < database/schema.sql`
2. Edit `config/config.php` (DB user/pass)
3. `php scripts/create_admin.php "Moses" you@example.com "YourPassword" "MBADIFA SACCO"`
4. `php -S localhost:8000 -t public dev-router.php`  (dev-router.php mimics .htaccess locally)
5. Open http://localhost:8000/ or http://localhost:8000/index

## Clean URLs (no .php)
- `/`, `/index`, `/login`, `/dashboard`. No file extension anywhere.
- Typing `/index.php` or `/login.php` 301-redirects to `/index` or `/login`.
- Always build links with `url('login')`, never hard-code `login.php`.
- Add a page: add a route in `public/index.php`, a controller method, and a view in `app/Views`.

## Apache
Point the domain/subdomain DocumentRoot to `/public` (needs `AllowOverride All` + mod_rewrite).
If you can't change DocumentRoot, the root `.htaccess` forwards everything into `/public`.

## Nginx
```
root /var/www/saccoplus/public;
index index.php;
location / { try_files $uri $uri/ /index.php?$query_string; }
location ~ \.php$ { include fastcgi_params; fastcgi_pass unix:/run/php/php8.2-fpm.sock; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; }
# optional: hide .php if someone types it
if ($request_uri ~ ^(.+)\.php$) { return 301 $1; }
```
