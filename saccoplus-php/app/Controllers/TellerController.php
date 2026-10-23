<?php

namespace App\Controllers;

use App\Core\View;
use App\Core\Auth;
use App\Core\Csrf;
use App\Core\Context;
use App\Services\TellerService;
use App\Models\Member;
use Exception;

class TellerController
{
    private $tellerService;
    
    public function __construct()
    {
        $this->tellerService = new TellerService();
    }
    
    /**
     * Teller dashboard
     */
    public function index()
    {
        Auth::require();
        
        $today = date('Y-m-d');
        $summary = $this->tellerService->getDailySummary($today, Auth::user()['id']);
        $recentTransactions = $this->tellerService->getRecentTransactions(20);
        
        View::render('teller/index', [
            'summary' => $summary,
            'recent_transactions' => $recentTransactions,
            'date' => $today
        ]);
    }
    
    /**
     * Show deposit form
     */
    public function showDeposit()
    {
        Auth::require();
        
        $memberId = $_GET['member_id'] ?? null;
        $member = null;
        
        if ($memberId) {
            $saccoId = Context::requireSacco();
            $member = Member::getById($memberId, $saccoId);
        }
        
        View::render('teller/deposit', [
            'member' => $member,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Process deposit
     */
    public function deposit()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $memberId = (int)($_POST['member_id'] ?? 0);
            $amount = (float)($_POST['amount'] ?? 0);
            $notes = $_POST['notes'] ?? '';
            $transactionDate = $_POST['transaction_date'] ?? date('Y-m-d');
            
            if (!$memberId || $amount <= 0) {
                throw new Exception("Invalid member or amount");
            }
            
            $result = $this->tellerService->deposit(
                $memberId,
                $amount,
                $notes,
                Auth::user()['id'],
                $transactionDate
            );
            
            $_SESSION['success'] = "Deposit successful. New balance: UGX " . number_format($result['new_balance']);
            redirect('/teller/deposit?member_id=' . $memberId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/teller/deposit' . (isset($_POST['member_id']) ? '?member_id=' . $_POST['member_id'] : ''));
        }
    }
    
    /**
     * Show withdrawal form
     */
    public function showWithdraw()
    {
        Auth::require();
        
        $memberId = $_GET['member_id'] ?? null;
        $member = null;
        
        if ($memberId) {
            $saccoId = Context::requireSacco();
            $member = Member::getById($memberId, $saccoId);
        }
        
        View::render('teller/withdraw', [
            'member' => $member,
            'csrf_token' => Csrf::generate()
        ]);
    }
    
    /**
     * Process withdrawal
     */
    public function withdraw()
    {
        Auth::require();
        Csrf::verify($_POST['csrf_token'] ?? '');
        
        try {
            $memberId = (int)($_POST['member_id'] ?? 0);
            $amount = (float)($_POST['amount'] ?? 0);
            $notes = $_POST['notes'] ?? '';
            $transactionDate = $_POST['transaction_date'] ?? date('Y-m-d');
            
            if (!$memberId || $amount <= 0) {
                throw new Exception("Invalid member or amount");
            }
            
            $result = $this->tellerService->withdraw(
                $memberId,
                $amount,
                $notes,
                Auth::user()['id'],
                $transactionDate
            );
            
            $_SESSION['success'] = "Withdrawal successful. New balance: UGX " . number_format($result['new_balance']);
            redirect('/teller/withdraw?member_id=' . $memberId);
            
        } catch (Exception $e) {
            $_SESSION['error'] = $e->getMessage();
            $_SESSION['old'] = $_POST;
            redirect('/teller/withdraw' . (isset($_POST['member_id']) ? '?member_id=' . $_POST['member_id'] : ''));
        }
    }
}
