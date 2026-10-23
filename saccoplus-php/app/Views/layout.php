<?php use App\Core\{Auth, Csrf}; ?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($title ?? config('app_name')) ?> · <?= e(config('app_name')) ?></title>
<link rel="stylesheet" href="<?= asset('css/app.css') ?>">
</head>
<body>
<header class="topbar">
  <div class="wrap topbar-in">
    <a class="brand" href="<?= url('index') ?>"><span class="brand-mark">S+</span> <?= e(config('app_name')) ?></a>
    <nav class="nav">
      <a href="<?= url('index') ?>">Home</a>
      <?php if (Auth::check()): ?>
        <a href="<?= url('dashboard') ?>">Dashboard</a>
        <a href="<?= url('teller') ?>">Teller</a>
        <a href="<?= url('members') ?>">Members</a>
        <form method="post" action="<?= url('logout') ?>" class="inline">
          <?= Csrf::field() ?>
          <button class="btn btn-ghost" type="submit">Sign out</button>
        </form>
      <?php else: ?>
        <a class="btn btn-primary" href="<?= url('login') ?>">Sign in</a>
      <?php endif; ?>
    </nav>
  </div>
</header>

<main>
<?php if ($m = flash('error')): ?><div class="wrap"><div class="alert alert-error"><?= e($m) ?></div></div><?php endif; ?>
<?php if ($m = flash('success')): ?><div class="wrap"><div class="alert alert-ok"><?= e($m) ?></div></div><?php endif; ?>
<?= $content ?>
</main>

<footer class="footer">
  <div class="wrap">© <?= date('Y') ?> <?= e(config('app_name')) ?> · Built by Infinitech Innovations Ltd</div>
</footer>
</body>
</html>
