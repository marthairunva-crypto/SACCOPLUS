<?php

namespace App\Services;

use App\Core\DB;
use App\Core\Context;
use App\Models\Member;
use Exception;

class TellerService
{
    private $journalService;
    
    public function __construct()
    {
        $this->journalService = new JournalService();
    }
    
    /**
     * Process deposit
     * 
     * DR Cash on Hand (1010)
     * CR Member Savings Deposits (2010)
     */
    public function deposit($memberId, $amount, $notes, $userId, $transactionDate = null, $source = 'cash')
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::requireBranch();
        
        if ($amount <= 0) {
            throw new Exception("Deposit amount must be positive");
        }
        
        $transactionDate = $transactionDate ?? date('Y-m-d');
        
        // Validate transaction date (max 48h backdate)
        $minDate = date('Y-m-d', strtotime('-48 hours'));
        $maxDate = date('Y-m-d');
        
        if ($transactionDate < $minDate || $transactionDate > $maxDate) {
            throw new Exception("Transaction date must be within the last 48 hours");
        }
        
        DB::beginTransaction();
        
        try {
            // Get member and savings account
            $member = Member::getById($memberId, $saccoId);
            if (!$member) {
                throw new Exception("Member not found");
            }
            
            $savingsAccount = Member::getAccount($memberId, 'savings');
            if (!$savingsAccount) {
                throw new Exception("Member savings account not found");
            }
            
            // Get GL accounts
            $cashGLId = Context::getGLAccount('1010'); // Cash on Hand
            $savingsGLId = Context::getGLAccount('2010'); // Member Savings Deposits
            
            if (!$cashGLId || !$savingsGLId) {
                throw new Exception("GL accounts not configured");
            }
            
            // Post journal entry
            $entryId = $this->journalService->postEntry(
                $saccoId,
                $branchId,
                'deposit',
                "Deposit from {$member['full_name']} ({$member['member_no']})" . 
                    ($notes ? ". {$notes}" : ""),
                [
                    // DR Cash on Hand
                    [
                        'gl_account_id' => $cashGLId,
                        'debit' => $amount,
                        'credit' => 0,
                        'member_account_id' => null,
                        'loan_id' => null
                    ],
                    // CR Member Savings
                    [
                        'gl_account_id' => $savingsGLId,
                        'debit' => 0,
                        'credit' => $amount,
                        'member_account_id' => $savingsAccount['id'],
                        'loan_id' => null
                    ]
                ],
                $userId,
                $transactionDate
            );
            
            // Audit log
            AuditService::log(
                'teller_deposit',
                'journal_entries',
                (string)$entryId,
                null,
                [
                    'member_id' => $memberId,
                    'amount' => $amount,
                    'source' => $source,
                    'notes' => $notes
                ],
                $userId
            );
            
            DB::commit();
            
            // Get new balance
            $newBalance = $this->journalService->getMemberAccountBalance($saccoId, $savingsAccount['id']);
            
            return [
                'entry_id' => $entryId,
                'new_balance' => $newBalance
            ];
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Deposit failed: " . $e->getMessage());
        }
    }
    
    /**
     * Process withdrawal
     * 
     * DR Member Savings Deposits (2010)
     * CR Cash on Hand (1010)
     */
    public function withdraw($memberId, $amount, $notes, $userId, $transactionDate = null)
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::requireBranch();
        
        if ($amount <= 0) {
            throw new Exception("Withdrawal amount must be positive");
        }
        
        $transactionDate = $transactionDate ?? date('Y-m-d');
        
        // Validate transaction date
        $minDate = date('Y-m-d', strtotime('-48 hours'));
        $maxDate = date('Y-m-d');
        
        if ($transactionDate < $minDate || $transactionDate > $maxDate) {
            throw new Exception("Transaction date must be within the last 48 hours");
        }
        
        DB::beginTransaction();
        
        try {
            // Get member and savings account
            $member = Member::getById($memberId, $saccoId);
            if (!$member) {
                throw new Exception("Member not found");
            }
            
            $savingsAccount = Member::getAccount($memberId, 'savings');
            if (!$savingsAccount) {
                throw new Exception("Member savings account not found");
            }
            
            // Check balance
            $currentBalance = $this->journalService->getMemberAccountBalance($saccoId, $savingsAccount['id']);
            if ($currentBalance < $amount) {
                throw new Exception("Insufficient balance. Available: UGX " . number_format($currentBalance));
            }
            
            // Get GL accounts
            $cashGLId = Context::getGLAccount('1010'); // Cash on Hand
            $savingsGLId = Context::getGLAccount('2010'); // Member Savings Deposits
            
            if (!$cashGLId || !$savingsGLId) {
                throw new Exception("GL accounts not configured");
            }
            
            // Post journal entry
            $entryId = $this->journalService->postEntry(
                $saccoId,
                $branchId,
                'withdrawal',
                "Withdrawal by {$member['full_name']} ({$member['member_no']})" . 
                    ($notes ? ". {$notes}" : ""),
                [
                    // DR Member Savings
                    [
                        'gl_account_id' => $savingsGLId,
                        'debit' => $amount,
                        'credit' => 0,
                        'member_account_id' => $savingsAccount['id'],
                        'loan_id' => null
                    ],
                    // CR Cash on Hand
                    [
                        'gl_account_id' => $cashGLId,
                        'debit' => 0,
                        'credit' => $amount,
                        'member_account_id' => null,
                        'loan_id' => null
                    ]
                ],
                $userId,
                $transactionDate
            );
            
            // Audit log
            AuditService::log(
                'teller_withdrawal',
                'journal_entries',
                (string)$entryId,
                ['balance' => $currentBalance],
                [
                    'member_id' => $memberId,
                    'amount' => $amount,
                    'notes' => $notes
                ],
                $userId
            );
            
            DB::commit();
            
            // Get new balance
            $newBalance = $this->journalService->getMemberAccountBalance($saccoId, $savingsAccount['id']);
            
            return [
                'entry_id' => $entryId,
                'new_balance' => $newBalance
            ];
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Withdrawal failed: " . $e->getMessage());
        }
    }
    
    /**
     * Get daily summary for teller
     */
    public function getDailySummary($date, $userId = null)
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::branchId();
        
        $sql = "
            SELECT 
                je.txn_type,
                COUNT(*) as count,
                SUM(CASE WHEN je.txn_type = 'deposit' THEN 
                    (SELECT SUM(credit) FROM journal_lines WHERE entry_id = je.id AND member_account_id IS NOT NULL)
                    ELSE 0 END) as total_deposits,
                SUM(CASE WHEN je.txn_type = 'withdrawal' THEN 
                    (SELECT SUM(debit) FROM journal_lines WHERE entry_id = je.id AND member_account_id IS NOT NULL)
                    ELSE 0 END) as total_withdrawals
            FROM journal_entries je
            WHERE je.sacco_id = ?
              AND je.branch_id = ?
              AND DATE(je.value_date) = ?
        ";
        
        $params = [$saccoId, $branchId, $date];
        
        if ($userId) {
            $sql .= " AND je.posted_by = ?";
            $params[] = $userId;
        }
        
        $sql .= " GROUP BY je.txn_type";
        
        return DB::query($sql, $params);
    }
    
    /**
     * Get recent transactions for teller dashboard
     */
    public function getRecentTransactions($limit = 20)
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::branchId();
        
        $sql = "
            SELECT 
                je.id,
                je.txn_ref,
                je.txn_type,
                je.description,
                je.value_date,
                je.created_at,
                m.full_name as member_name,
                m.member_no,
                u.name as posted_by_name,
                (SELECT SUM(credit) FROM journal_lines WHERE entry_id = je.id AND member_account_id IS NOT NULL) as amount
            FROM journal_entries je
            LEFT JOIN journal_lines jl ON je.id = jl.entry_id AND jl.member_account_id IS NOT NULL
            LEFT JOIN member_accounts ma ON jl.member_account_id = ma.id
            LEFT JOIN members m ON ma.member_id = m.id
            LEFT JOIN users u ON je.posted_by = u.id
            WHERE je.sacco_id = ?
              AND je.branch_id = ?
              AND je.txn_type IN ('deposit', 'withdrawal')
            GROUP BY je.id
            ORDER BY je.created_at DESC
            LIMIT ?
        ";
        
        return DB::query($sql, [$saccoId, $branchId, $limit]);
    }
}
