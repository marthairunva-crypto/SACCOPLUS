<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\{Auth, View, Csrf};
use App\Services\TellerService;

class TellerController
{
    /**
     * Teller dashboard - today's summary + recent transactions
     */
    public function index(): void
    {
        Auth::requireAuth(['teller', 'manager', 'admin']);
        
        $user = Auth::user();
        $today = date('Y-m-d');
        
        $summary = TellerService::getDailySummary($user['sacco_id'], $user['id'], $today);
        $recentTransactions = TellerService::getRecentTransactions($user['sacco_id'], $user['id'], 10);
        
        View::render('teller/index', [
            'summary' => $summary,
            'recent' => $recentTransactions,
            'date' => $today,
        ]);
    }

    /**
     * Show deposit form
     */
    public function showDeposit(): void
    {
        Auth::requireAuth(['teller', 'manager', 'admin']);
        View::render('teller/deposit');
    }

    /**
     * Process deposit
     */
    public function deposit(): void
    {
        Auth::requireAuth(['teller', 'manager', 'admin']);
        Csrf::validate();
        
        $memberId = (int) ($_POST['member_id'] ?? 0);
        $amount = (int) ($_POST['amount'] ?? 0);
        $paymentMethod = trim($_POST['payment_method'] ?? 'Cash');
        $referenceNo = !empty($_POST['reference_no']) ? trim($_POST['reference_no']) : null;
        $notes = trim($_POST['notes'] ?? '');
        $transactionDate = $_POST['transaction_date'] ?? date('Y-m-d');
        
        // Validate transaction date (max 48 hours back)
        $maxBackdate = date('Y-m-d', strtotime('-48 hours'));
        if ($transactionDate < $maxBackdate) {
            flash('error', 'Cannot backdate more than 48 hours');
            redirect('teller/deposit');
            return;
        }
        
        if ($transactionDate > date('Y-m-d')) {
            flash('error', 'Cannot use future date');
            redirect('teller/deposit');
            return;
        }
        
        $result = TellerService::deposit(
            $memberId,
            $amount,
            $paymentMethod,
            $referenceNo,
            $notes,
            Auth::user()['id'],
            $transactionDate
        );
        
        if ($result['success']) {
            flash('success', $result['message'] . '. New balance: UGX ' . number_format($result['new_balance']));
            redirect('teller');
        } else {
            flash('error', $result['message']);
            redirect('teller/deposit');
        }
    }

    /**
     * Show withdrawal form
     */
    public function showWithdraw(): void
    {
        Auth::requireAuth(['teller', 'manager', 'admin']);
        View::render('teller/withdraw');
    }

    /**
     * Process withdrawal
     */
    public function withdraw(): void
    {
        Auth::requireAuth(['teller', 'manager', 'admin']);
        Csrf::validate();
        
        $memberId = (int) ($_POST['member_id'] ?? 0);
        $amount = (int) ($_POST['amount'] ?? 0);
        $destination = trim($_POST['destination'] ?? 'Cash');
        $referenceNo = !empty($_POST['reference_no']) ? trim($_POST['reference_no']) : null;
        $notes = trim($_POST['notes'] ?? '');
        $transactionDate = $_POST['transaction_date'] ?? date('Y-m-d');
        
        // Validate transaction date
        $maxBackdate = date('Y-m-d', strtotime('-48 hours'));
        if ($transactionDate < $maxBackdate) {
            flash('error', 'Cannot backdate more than 48 hours');
            redirect('teller/withdraw');
            return;
        }
        
        if ($transactionDate > date('Y-m-d')) {
            flash('error', 'Cannot use future date');
            redirect('teller/withdraw');
            return;
        }
        
        $result = TellerService::withdraw(
            $memberId,
            $amount,
            $destination,
            $referenceNo,
            $notes,
            Auth::user()['id'],
            $transactionDate
        );
        
        if ($result['success']) {
            flash('success', $result['message'] . '. New balance: UGX ' . number_format($result['new_balance']));
            redirect('teller');
        } else {
            flash('error', $result['message']);
            redirect('teller/withdraw');
        }
    }
}
