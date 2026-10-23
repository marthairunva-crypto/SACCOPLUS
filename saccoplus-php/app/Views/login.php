<?php use App\Core\Csrf; ?>
<section class="section">
  <div class="wrap narrow">
    <div class="card">
      <h2>Sign in</h2>
      <p class="muted">Use your SACCO staff account.</p>
      <form method="post" action="<?= url('login') ?>" autocomplete="on">
        <?= Csrf::field() ?>
        <label for="email">Email</label>
        <input id="email" name="email" type="email" required autofocus value="<?= old('email') ?>">
        <label for="password">Password</label>
        <input id="password" name="password" type="password" required>
        <button class="btn btn-primary btn-block" type="submit">Sign in</button>
      </form>
    </div>
  </div>
</section>
