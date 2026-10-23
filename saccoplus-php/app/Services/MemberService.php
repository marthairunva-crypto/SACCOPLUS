<?php

namespace App\Services;

use App\Core\DB;
use App\Core\Context;
use App\Models\Member;
use Exception;

class MemberService
{
    private $journalService;
    
    public function __construct()
    {
        $this->journalService = new JournalService();
    }
    
    /**
     * Create new member with accounts
     */
    public function createMember($data, $userId)
    {
        $saccoId = Context::requireSacco();
        $branchId = $data['branch_id'] ?? Context::requireBranch();
        
        DB::beginTransaction();
        
        try {
            // Generate member number
            $data['member_no'] = Member::generateMemberNumber($saccoId);
            $data['sacco_id'] = $saccoId;
            $data['branch_id'] = $branchId;
            $data['created_by'] = $userId;
            
            // Create member
            $memberId = Member::create($data);
            
            // Get GL accounts for member accounts
            $savingsGLId = Context::getGLAccount('2010'); // Member Savings Deposits
            $sharesGLId = Context::getGLAccount('2020');  // Member Shares
            
            if (!$savingsGLId || !$sharesGLId) {
                throw new Exception("GL accounts not found. Please run GL account seeds.");
            }
            
            // Create savings account
            Member::createAccount($memberId, 'savings', $saccoId, $branchId, $savingsGLId);
            
            // Create shares account
            Member::createAccount($memberId, 'shares', $saccoId, $branchId, $sharesGLId);
            
            // Audit log
            AuditService::log(
                'member_created',
                'members',
                (string)$memberId,
                null,
                $data,
                $userId
            );
            
            DB::commit();
            return $memberId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Failed to create member: " . $e->getMessage());
        }
    }
    
    /**
     * Get member summary with balances and recent transactions
     */
    public function getMemberSummary($memberId)
    {
        $saccoId = Context::requireSacco();
        
        $member = Member::getById($memberId, $saccoId);
        if (!$member) {
            throw new Exception("Member not found");
        }
        
        // Get savings account
        $savingsAccount = Member::getAccount($memberId, 'savings');
        $sharesAccount = Member::getAccount($memberId, 'shares');
        
        // Get transaction summary
        $txnSummary = Member::getTransactionSummary($memberId, 30);
        
        // Get recent transactions (last 10)
        $recentTxns = [];
        if ($savingsAccount) {
            $recentTxns = $this->journalService->getMemberAccountStatement(
                $saccoId,
                $savingsAccount['id'],
                date('Y-m-d', strtotime('-90 days')),
                date('Y-m-d'),
                10,
                0
            );
        }
        
        // Get active loans count
        $loansCount = DB::query(
            "SELECT COUNT(*) as count FROM loans WHERE member_id = ? AND status IN ('active', 'approved')",
            [$memberId]
        )[0]['count'] ?? 0;
        
        return [
            'member' => $member,
            'savings_account' => $savingsAccount,
            'shares_account' => $sharesAccount,
            'transaction_summary' => $txnSummary,
            'recent_transactions' => $recentTxns,
            'active_loans_count' => $loansCount
        ];
    }
    
    /**
     * Get member account statement
     */
    public function getMemberStatement($memberId, $startDate, $endDate, $accountType = 'savings')
    {
        $saccoId = Context::requireSacco();
        
        $account = Member::getAccount($memberId, $accountType);
        if (!$account) {
            throw new Exception("Member {$accountType} account not found");
        }
        
        // Get opening balance
        $openingBalance = 0;
        if ($startDate > $account['created_at']) {
            $openingBalance = $this->journalService->getMemberAccountBalance($saccoId, $account['id']);
            
            // Subtract transactions in the statement period
            $periodTxns = $this->journalService->getMemberAccountStatement(
                $saccoId,
                $account['id'],
                $startDate,
                $endDate,
                1000,
                0
            );
            
            foreach ($periodTxns as $txn) {
                $openingBalance -= ($txn['credit'] - $txn['debit']);
            }
        }
        
        // Get transactions
        $transactions = $this->journalService->getMemberAccountStatement(
            $saccoId,
            $account['id'],
            $startDate,
            $endDate,
            1000,
            0
        );
        
        // Calculate running balance
        $runningBalance = $openingBalance;
        foreach ($transactions as &$txn) {
            $runningBalance += ($txn['credit'] - $txn['debit']);
            $txn['running_balance'] = $runningBalance;
        }
        
        // Get closing balance
        $closingBalance = $this->journalService->getMemberAccountBalance($saccoId, $account['id']);
        
        return [
            'member' => Member::getById($memberId, $saccoId),
            'account' => $account,
            'opening_balance' => $openingBalance,
            'transactions' => $transactions,
            'closing_balance' => $closingBalance,
            'start_date' => $startDate,
            'end_date' => $endDate
        ];
    }
}
