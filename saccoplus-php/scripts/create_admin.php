<?php
// Usage: php scripts/create_admin.php "Moses" admin@example.com "StrongPassword" "MBADIFA SACCO"
if (PHP_SAPI !== 'cli') exit('CLI only');
require dirname(__DIR__) . '/app/bootstrap.php';
use App\Core\DB;

[$_, $name, $email, $pass, $sacco] = array_pad($argv, 5, null);
if (!$name || !$email || !$pass) exit("Usage: php scripts/create_admin.php \"Full Name\" email password [\"SACCO name\"]\n");

$pdo = DB::pdo();
$sacco = $sacco ?: 'MBADIFA SACCO';
$st = $pdo->prepare('SELECT id FROM saccos WHERE name = ?'); $st->execute([$sacco]);
$sid = $st->fetchColumn();
if (!$sid) { $pdo->prepare('INSERT INTO saccos (name) VALUES (?)')->execute([$sacco]); $sid = $pdo->lastInsertId(); }

$pdo->prepare('INSERT INTO users (sacco_id, full_name, email, password_hash, role) VALUES (?,?,?,?,?)')
    ->execute([$sid, $name, $email, password_hash($pass, PASSWORD_DEFAULT), 'admin']);
echo "Admin created: $email (SACCO: $sacco)\n";
