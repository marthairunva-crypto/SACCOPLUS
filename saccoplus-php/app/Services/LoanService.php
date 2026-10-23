<?php

namespace App\Services;

use App\Core\DB;
use App\Core\Context;
use App\Models\Loan;
use App\Models\Member;
use Exception;

class LoanService
{
    private $journalService;
    
    public function __construct()
    {
        $this->journalService = new JournalService();
    }
    
    /**
     * Apply for a loan
     */
    public function applyForLoan($data, $userId)
    {
        $saccoId = Context::requireSacco();
        $branchId = $data['branch_id'] ?? Context::requireBranch();
        
        // Validate member exists
        $member = Member::getById($data['member_id'], $saccoId);
        if (!$member) {
            throw new Exception("Member not found");
        }
        
        // Check active loans
        $activeLoans = $this->getActiveLoanCount($data['member_id']);
        if ($activeLoans >= 3) {
            throw new Exception("Member already has 3 active loans. Maximum reached.");
        }
        
        DB::beginTransaction();
        
        try {
            // Generate loan number
            $loanNo = $this->generateLoanNumber($saccoId);
            
            $sql = "
                INSERT INTO loans (
                    sacco_id, branch_id, member_id, product_id, loan_no,
                    principal, term_months, interest_rate, interest_method,
                    status, applied_on, purpose
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
            ";
            
            DB::execute($sql, [
                $saccoId,
                $branchId,
                $data['member_id'],
                $data['product_id'],
                $loanNo,
                $data['principal'],
                $data['term_months'],
                $data['interest_rate'],
                $data['interest_method'] ?? 'reducing',
                $data['applied_on'] ?? date('Y-m-d'),
                $data['purpose'] ?? null
            ]);
            
            $loanId = DB::lastInsertId();
            
            // Audit log
            AuditService::log(
                'loan_application',
                'loans',
                (string)$loanId,
                null,
                $data,
                $userId
            );
            
            DB::commit();
            return $loanId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Failed to apply for loan: " . $e->getMessage());
        }
    }
    
    /**
     * Approve loan
     */
    public function approveLoan($loanId, $notes, $userId)
    {
        $saccoId = Context::requireSacco();
        
        $loan = $this->getLoanById($loanId, $saccoId);
        if (!$loan) {
            throw new Exception("Loan not found");
        }
        
        if ($loan['status'] !== 'pending') {
            throw new Exception("Only pending loans can be approved");
        }
        
        $sql = "UPDATE loans SET status = 'approved', approved_by = ?, approved_on = ? WHERE id = ? AND sacco_id = ?";
        DB::execute($sql, [$userId, date('Y-m-d'), $loanId, $saccoId]);
        
        // Audit log
        AuditService::log(
            'loan_approval',
            'loans',
            (string)$loanId,
            ['status' => 'pending'],
            ['status' => 'approved', 'notes' => $notes],
            $userId
        );
        
        return true;
    }
    
    /**
     * Disburse loan
     * 
     * DR Loans Receivable - Principal (1100)
     * CR Member Savings Deposits (2010)
     */
    public function disburseLoan($loanId, $disbursementDate, $userId)
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::requireBranch();
        
        DB::beginTransaction();
        
        try {
            $loan = $this->getLoanById($loanId, $saccoId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            if ($loan['status'] !== 'approved') {
                throw new Exception("Only approved loans can be disbursed");
            }
            
            $principal = $loan['principal'];
            $memberId = $loan['member_id'];
            
            // Get member savings account
            $savingsAccount = Member::getAccount($memberId, 'savings');
            if (!$savingsAccount) {
                throw new Exception("Member savings account not found");
            }
            
            // Get GL accounts
            $loansPrincipalGLId = Context::getGLAccount('1100'); // Loans Receivable - Principal
            $savingsGLId = Context::getGLAccount('2010'); // Member Savings Deposits
            
            if (!$loansPrincipalGLId || !$savingsGLId) {
                throw new Exception("GL accounts not configured");
            }
            
            // Calculate first due date
            $firstDueDate = date('Y-m-d', strtotime($disbursementDate . ' +1 month'));
            
            // Post journal entry
            $entryId = $this->journalService->postEntry(
                $saccoId,
                $branchId,
                'loan_disbursement',
                "Loan disbursement: {$loan['loan_no']}",
                [
                    // DR Loans Receivable - Principal
                    [
                        'gl_account_id' => $loansPrincipalGLId,
                        'debit' => $principal,
                        'credit' => 0,
                        'member_account_id' => null,
                        'loan_id' => $loanId
                    ],
                    // CR Member Savings
                    [
                        'gl_account_id' => $savingsGLId,
                        'debit' => 0,
                        'credit' => $principal,
                        'member_account_id' => $savingsAccount['id'],
                        'loan_id' => $loanId
                    ]
                ],
                $userId,
                $disbursementDate
            );
            
            // Update loan
            $sql = "UPDATE loans SET status = 'active', disbursed_on = ?, first_due_date = ? WHERE id = ?";
            DB::execute($sql, [$disbursementDate, $firstDueDate, $loanId]);
            
            // Generate repayment schedule
            $this->generateSchedule($loanId, $loan, $firstDueDate);
            
            // Audit log
            AuditService::log(
                'loan_disbursement',
                'loans',
                (string)$loanId,
                ['status' => 'approved'],
                ['status' => 'active', 'disbursed_on' => $disbursementDate, 'entry_id' => $entryId],
                $userId
            );
            
            DB::commit();
            return $entryId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Disbursement failed: " . $e->getMessage());
        }
    }
    
    /**
     * Record loan repayment
     * 
     * DR Member Savings Deposits (2010)
     * CR Loans Receivable - Principal (1100)
     * CR Loans Receivable - Interest (1110)
     * CR Loans Receivable - Penalties (1120)
     */
    public function recordRepayment($loanId, $amount, $paymentDate, $notes, $userId)
    {
        $saccoId = Context::requireSacco();
        $branchId = Context::requireBranch();
        
        if ($amount <= 0) {
            throw new Exception("Repayment amount must be positive");
        }
        
        DB::beginTransaction();
        
        try {
            $loan = $this->getLoanById($loanId, $saccoId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            if ($loan['status'] !== 'active') {
                throw new Exception("Only active loans can receive payments");
            }
            
            // Get member savings account
            $savingsAccount = Member::getAccount($loan['member_id'], 'savings');
            if (!$savingsAccount) {
                throw new Exception("Member savings account not found");
            }
            
            // Check balance
            $balance = $this->journalService->getMemberAccountBalance($saccoId, $savingsAccount['id']);
            if ($balance < $amount) {
                throw new Exception("Insufficient savings balance. Available: UGX " . number_format($balance));
            }
            
            // Calculate allocation (penalties → interest → principal)
            $outstandingBalances = $this->getOutstandingBalances($loanId);
            $allocation = $this->allocatePayment($amount, $outstandingBalances);
            
            // Get GL accounts
            $savingsGLId = Context::getGLAccount('2010'); // Member Savings
            $loansPrincipalGLId = Context::getGLAccount('1100'); // Loans Receivable - Principal
            $loansInterestGLId = Context::getGLAccount('1110'); // Loans Receivable - Interest
            $loansPenaltyGLId = Context::getGLAccount('1120'); // Loans Receivable - Penalties
            
            // Build journal lines
            $lines = [];
            
            // DR Member Savings
            $lines[] = [
                'gl_account_id' => $savingsGLId,
                'debit' => $amount,
                'credit' => 0,
                'member_account_id' => $savingsAccount['id'],
                'loan_id' => $loanId
            ];
            
            // CR Penalties (if any)
            if ($allocation['penalty'] > 0) {
                $lines[] = [
                    'gl_account_id' => $loansPenaltyGLId,
                    'debit' => 0,
                    'credit' => $allocation['penalty'],
                    'member_account_id' => null,
                    'loan_id' => $loanId
                ];
            }
            
            // CR Interest
            if ($allocation['interest'] > 0) {
                $lines[] = [
                    'gl_account_id' => $loansInterestGLId,
                    'debit' => 0,
                    'credit' => $allocation['interest'],
                    'member_account_id' => null,
                    'loan_id' => $loanId
                ];
            }
            
            // CR Principal
            if ($allocation['principal'] > 0) {
                $lines[] = [
                    'gl_account_id' => $loansPrincipalGLId,
                    'debit' => 0,
                    'credit' => $allocation['principal'],
                    'member_account_id' => null,
                    'loan_id' => $loanId
                ];
            }
            
            // Post journal entry
            $entryId = $this->journalService->postEntry(
                $saccoId,
                $branchId,
                'loan_repayment',
                "Loan repayment: {$loan['loan_no']} - P: {$allocation['principal']}, I: {$allocation['interest']}" .
                    ($allocation['penalty'] > 0 ? ", Pen: {$allocation['penalty']}" : "") .
                    ($notes ? ". {$notes}" : ""),
                $lines,
                $userId,
                $paymentDate
            );
            
            // Record in loan_repayments table
            $sql = "
                INSERT INTO loan_repayments (
                    sacco_id, branch_id, loan_id, journal_entry_id,
                    paid_on, amount, to_principal, to_interest, to_penalty, source
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'savings')
            ";
            
            DB::execute($sql, [
                $saccoId,
                $branchId,
                $loanId,
                $entryId,
                $paymentDate,
                $amount,
                $allocation['principal'],
                $allocation['interest'],
                $allocation['penalty']
            ]);
            
            // Update schedule
            $this->updateSchedule($loanId, $allocation);
            
            // Check if loan is fully paid
            $newBalances = $this->getOutstandingBalances($loanId);
            if ($newBalances['total'] <= 0.01) {
                DB::execute("UPDATE loans SET status = 'cleared' WHERE id = ?", [$loanId]);
            }
            
            // Audit log
            AuditService::log(
                'loan_repayment',
                'loan_repayments',
                (string)$entryId,
                $outstandingBalances,
                $allocation,
                $userId
            );
            
            DB::commit();
            return $entryId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Repayment failed: " . $e->getMessage());
        }
    }
    
    /**
     * Generate repayment schedule
     */
    private function generateSchedule($loanId, $loan, $firstDueDate)
    {
        $saccoId = Context::requireSacco();
        $principal = $loan['principal'];
        $annualRate = $loan['interest_rate'] / 100;
        $termMonths = $loan['term_months'];
        $method = $loan['interest_method'];
        
        if ($method === 'flat') {
            // Flat interest: Total interest = Principal * Rate * Term
            $totalInterest = $principal * $annualRate * ($termMonths / 12);
            $monthlyPrincipal = $principal / $termMonths;
            $monthlyInterest = $totalInterest / $termMonths;
            
            for ($i = 1; $i <= $termMonths; $i++) {
                $dueDate = date('Y-m-d', strtotime($firstDueDate . ' +' . ($i - 1) . ' month'));
                
                $sql = "
                    INSERT INTO loan_schedule (
                        sacco_id, loan_id, installment_no, due_date,
                        principal_due, interest_due
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ";
                
                DB::execute($sql, [
                    $saccoId,
                    $loanId,
                    $i,
                    $dueDate,
                    $monthlyPrincipal,
                    $monthlyInterest
                ]);
            }
        } else {
            // Reducing balance (amortized)
            $monthlyRate = $annualRate / 12;
            $monthlyPayment = $principal * $monthlyRate * pow(1 + $monthlyRate, $termMonths) 
                            / (pow(1 + $monthlyRate, $termMonths) - 1);
            
            $balance = $principal;
            
            for ($i = 1; $i <= $termMonths; $i++) {
                $dueDate = date('Y-m-d', strtotime($firstDueDate . ' +' . ($i - 1) . ' month'));
                $interestDue = $balance * $monthlyRate;
                $principalDue = $monthlyPayment - $interestDue;
                
                // Last payment adjusts for rounding
                if ($i === $termMonths) {
                    $principalDue = $balance;
                }
                
                $sql = "
                    INSERT INTO loan_schedule (
                        sacco_id, loan_id, installment_no, due_date,
                        principal_due, interest_due
                    ) VALUES (?, ?, ?, ?, ?, ?)
                ";
                
                DB::execute($sql, [
                    $saccoId,
                    $loanId,
                    $i,
                    $dueDate,
                    $principalDue,
                    $interestDue
                ]);
                
                $balance -= $principalDue;
            }
        }
    }
    
    /**
     * Get outstanding balances from schedule
     */
    private function getOutstandingBalances($loanId)
    {
        $sql = "
            SELECT 
                SUM(principal_due - principal_paid) as principal,
                SUM(interest_due - interest_paid) as interest,
                SUM(penalty_accrued - penalty_paid) as penalty
            FROM loan_schedule
            WHERE loan_id = ?
        ";
        
        $result = DB::query($sql, [$loanId]);
        $balances = $result[0] ?? [];
        
        return [
            'principal' => (float)($balances['principal'] ?? 0),
            'interest' => (float)($balances['interest'] ?? 0),
            'penalty' => (float)($balances['penalty'] ?? 0),
            'total' => (float)(($balances['principal'] ?? 0) + ($balances['interest'] ?? 0) + ($balances['penalty'] ?? 0))
        ];
    }
    
    /**
     * Allocate payment: penalties → interest → principal
     */
    private function allocatePayment($amount, $balances)
    {
        $allocation = ['penalty' => 0, 'interest' => 0, 'principal' => 0];
        $remaining = $amount;
        
        // Pay penalties first
        if ($balances['penalty'] > 0 && $remaining > 0) {
            $allocation['penalty'] = min($remaining, $balances['penalty']);
            $remaining -= $allocation['penalty'];
        }
        
        // Pay interest
        if ($balances['interest'] > 0 && $remaining > 0) {
            $allocation['interest'] = min($remaining, $balances['interest']);
            $remaining -= $allocation['interest'];
        }
        
        // Pay principal
        if ($balances['principal'] > 0 && $remaining > 0) {
            $allocation['principal'] = min($remaining, $balances['principal']);
            $remaining -= $allocation['principal'];
        }
        
        return $allocation;
    }
    
    /**
     * Update schedule after payment
     */
    private function updateSchedule($loanId, $allocation)
    {
        // Get unpaid installments
        $installments = DB::query(
            "SELECT * FROM loan_schedule 
             WHERE loan_id = ? 
             AND (principal_paid < principal_due OR interest_paid < interest_due OR penalty_paid < penalty_accrued)
             ORDER BY installment_no ASC",
            [$loanId]
        );
        
        $remainingPenalty = $allocation['penalty'];
        $remainingInterest = $allocation['interest'];
        $remainingPrincipal = $allocation['principal'];
        
        foreach ($installments as $inst) {
            if ($remainingPenalty <= 0 && $remainingInterest <= 0 && $remainingPrincipal <= 0) break;
            
            // Apply penalty
            $penaltyToApply = min($remainingPenalty, $inst['penalty_accrued'] - $inst['penalty_paid']);
            
            // Apply interest
            $interestToApply = min($remainingInterest, $inst['interest_due'] - $inst['interest_paid']);
            
            // Apply principal
            $principalToApply = min($remainingPrincipal, $inst['principal_due'] - $inst['principal_paid']);
            
            if ($penaltyToApply > 0 || $interestToApply > 0 || $principalToApply > 0) {
                $sql = "
                    UPDATE loan_schedule 
                    SET penalty_paid = penalty_paid + ?,
                        interest_paid = interest_paid + ?,
                        principal_paid = principal_paid + ?
                    WHERE id = ?
                ";
                
                DB::execute($sql, [
                    $penaltyToApply,
                    $interestToApply,
                    $principalToApply,
                    $inst['id']
                ]);
                
                $remainingPenalty -= $penaltyToApply;
                $remainingInterest -= $interestToApply;
                $remainingPrincipal -= $principalToApply;
            }
        }
    }
    
    /**
     * Get loan by ID
     */
    private function getLoanById($loanId, $saccoId)
    {
        $sql = "SELECT * FROM loans WHERE id = ? AND sacco_id = ?";
        $result = DB::query($sql, [$loanId, $saccoId]);
        return $result[0] ?? null;
    }
    
    /**
     * Get active loan count
     */
    private function getActiveLoanCount($memberId)
    {
        $sql = "SELECT COUNT(*) as count FROM loans WHERE member_id = ? AND status IN ('active', 'approved')";
        $result = DB::query($sql, [$memberId]);
        return $result[0]['count'] ?? 0;
    }
    
    /**
     * Generate loan number
     */
    private function generateLoanNumber($saccoId)
    {
        $prefix = 'LN';
        $year = date('Y');
        $month = date('m');
        
        $sql = "SELECT loan_no FROM loans WHERE sacco_id = ? AND loan_no LIKE ? ORDER BY id DESC LIMIT 1";
        $result = DB::query($sql, [$saccoId, "{$prefix}{$year}{$month}%"]);
        
        if (empty($result)) {
            $sequence = 1;
        } else {
            $lastNumber = $result[0]['loan_no'];
            $sequence = (int)substr($lastNumber, -4) + 1;
        }
        
        return sprintf("%s%s%s%04d", $prefix, $year, $month, $sequence);
    }
}
