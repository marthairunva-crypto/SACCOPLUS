<?php

namespace App\Services;

use App\Core\DB;
use App\Models\Loan;
use App\Models\Member;
use Exception;

class LoanService
{
    /**
     * Apply for a loan
     */
    public function applyForLoan($data, $userId)
    {
        // Validate member exists
        $member = Member::getById($data['member_id']);
        if (!$member) {
            throw new Exception("Member not found");
        }
        
        // Check if member has active loans
        $activeLoans = Loan::getActiveLoansByMember($data['member_id']);
        if ($activeLoans >= 3) {
            throw new Exception("Member already has 3 active loans. Maximum reached.");
        }
        
        // Generate loan number
        $data['loan_number'] = Loan::generateLoanNumber();
        $data['application_date'] = $data['application_date'] ?? date('Y-m-d');
        $data['applied_by'] = $userId;
        
        // Create loan
        $loanId = Loan::create($data);
        
        // Add note
        Loan::addNote($loanId, "Loan application submitted", 'general', $userId);
        
        // Audit log
        AuditService::log(
            'loan_application',
            'loans',
            $loanId,
            null,
            json_encode($data),
            $userId
        );
        
        return $loanId;
    }
    
    /**
     * Approve loan
     */
    public function approveLoan($loanId, $approvedAmount, $notes, $userId)
    {
        DB::beginTransaction();
        
        try {
            $loan = Loan::getById($loanId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            if ($loan['status'] !== 'pending') {
                throw new Exception("Only pending loans can be approved");
            }
            
            $oldData = json_encode($loan);
            
            // Update loan
            Loan::update($loanId, [
                'amount_approved' => $approvedAmount,
                'status' => 'approved',
                'approval_date' => date('Y-m-d'),
                'approved_by' => $userId,
                'approval_notes' => $notes
            ]);
            
            // Add note
            Loan::addNote($loanId, "Loan approved: UGX " . number_format($approvedAmount) . ". " . $notes, 'approval', $userId);
            
            // Audit log
            AuditService::log(
                'loan_approval',
                'loans',
                $loanId,
                $oldData,
                json_encode(['amount_approved' => $approvedAmount, 'status' => 'approved']),
                $userId
            );
            
            DB::commit();
            return true;
            
        } catch (Exception $e) {
            DB::rollback();
            throw $e;
        }
    }
    
    /**
     * Reject loan
     */
    public function rejectLoan($loanId, $reason, $userId)
    {
        $loan = Loan::getById($loanId);
        if (!$loan) {
            throw new Exception("Loan not found");
        }
        
        if ($loan['status'] !== 'pending') {
            throw new Exception("Only pending loans can be rejected");
        }
        
        Loan::update($loanId, [
            'status' => 'rejected',
            'rejection_reason' => $reason,
            'approved_by' => $userId,
            'approval_date' => date('Y-m-d')
        ]);
        
        Loan::addNote($loanId, "Loan rejected: " . $reason, 'approval', $userId);
        
        AuditService::log('loan_rejection', 'loans', $loanId, null, $reason, $userId);
        
        return true;
    }
    
    /**
     * Disburse loan
     */
    public function disburseLoan($loanId, $disbursementDate, $userId)
    {
        DB::beginTransaction();
        
        try {
            $loan = Loan::getById($loanId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            if ($loan['status'] !== 'approved') {
                throw new Exception("Only approved loans can be disbursed");
            }
            
            $amountApproved = $loan['amount_approved'];
            $memberId = $loan['member_id'];
            
            // Lock member row
            $member = DB::query(
                "SELECT * FROM members WHERE id = ? FOR UPDATE",
                [$memberId]
            )[0];
            
            // Calculate first payment date and maturity
            $firstPaymentDate = date('Y-m-d', strtotime($disbursementDate . ' +1 month'));
            $maturityDate = date('Y-m-d', strtotime($disbursementDate . ' +' . $loan['term_months'] . ' months'));
            
            // Update loan
            Loan::update($loanId, [
                'status' => 'active',
                'disbursement_date' => $disbursementDate,
                'disbursed_by' => $userId,
                'amount_disbursed' => $amountApproved,
                'principal_balance' => $amountApproved,
                'first_payment_date' => $firstPaymentDate,
                'maturity_date' => $maturityDate
            ]);
            
            // Credit member savings (loan disbursed to their account)
            $newBalance = $member['savings_balance'] + $amountApproved;
            DB::execute(
                "UPDATE members SET savings_balance = ? WHERE id = ?",
                [$newBalance, $memberId]
            );
            
            // Ledger entry
            LedgerService::recordTransaction(
                $memberId,
                'loan_disbursement',
                $amountApproved,
                0,
                $newBalance,
                "Loan {$loan['loan_number']} disbursed",
                $userId,
                null,
                $loanId,
                $disbursementDate
            );
            
            // Generate repayment schedule
            $this->generateSchedule($loanId, $loan['amount_approved'], $loan['interest_rate'], 
                                   $loan['term_months'], $firstPaymentDate, $loan['repayment_frequency']);
            
            // Add note
            Loan::addNote($loanId, "Loan disbursed: UGX " . number_format($amountApproved), 'disbursement', $userId);
            
            // Audit log
            AuditService::log('loan_disbursement', 'loans', $loanId, null, 
                            json_encode(['amount' => $amountApproved, 'date' => $disbursementDate]), $userId);
            
            DB::commit();
            return true;
            
        } catch (Exception $e) {
            DB::rollback();
            throw $e;
        }
    }
    
    /**
     * Generate loan repayment schedule
     */
    private function generateSchedule($loanId, $principal, $annualRate, $termMonths, $startDate, $frequency = 'monthly')
    {
        // Simple equal installment calculation
        $monthlyRate = ($annualRate / 100) / 12;
        $monthlyPayment = 0;
        
        if ($monthlyRate > 0) {
            // PMT formula: P * r * (1 + r)^n / ((1 + r)^n - 1)
            $monthlyPayment = $principal * $monthlyRate * pow(1 + $monthlyRate, $termMonths) 
                            / (pow(1 + $monthlyRate, $termMonths) - 1);
        } else {
            $monthlyPayment = $principal / $termMonths;
        }
        
        $balance = $principal;
        $currentDate = $startDate;
        
        for ($i = 1; $i <= $termMonths; $i++) {
            $interestDue = round($balance * $monthlyRate);
            $principalDue = round($monthlyPayment - $interestDue);
            
            // Last payment adjusts for rounding
            if ($i === $termMonths) {
                $principalDue = $balance;
                $totalDue = $principalDue + $interestDue;
            } else {
                $totalDue = round($monthlyPayment);
            }
            
            $sql = "
                INSERT INTO loan_schedules (
                    loan_id, installment_number, due_date,
                    principal_due, interest_due, total_due
                ) VALUES (?, ?, ?, ?, ?, ?)
            ";
            
            DB::execute($sql, [
                $loanId,
                $i,
                $currentDate,
                $principalDue,
                $interestDue,
                $totalDue
            ]);
            
            $balance -= $principalDue;
            $currentDate = date('Y-m-d', strtotime($currentDate . ' +1 month'));
        }
    }
    
    /**
     * Record loan repayment
     */
    public function recordRepayment($loanId, $amount, $paymentDate, $notes, $userId)
    {
        DB::beginTransaction();
        
        try {
            $loan = Loan::getById($loanId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            if (!in_array($loan['status'], ['active', 'disbursed'])) {
                throw new Exception("Only active loans can receive payments");
            }
            
            $memberId = $loan['member_id'];
            
            // Lock rows
            $member = DB::query("SELECT * FROM members WHERE id = ? FOR UPDATE", [$memberId])[0];
            $loanLocked = DB::query("SELECT * FROM loans WHERE id = ? FOR UPDATE", [$loanId])[0];
            
            // Check member has sufficient balance
            if ($member['savings_balance'] < $amount) {
                throw new Exception("Insufficient savings balance. Member has UGX " . 
                                  number_format($member['savings_balance']));
            }
            
            // Apply payment: penalties first, then interest, then principal
            $remaining = $amount;
            $penaltiesPaid = 0;
            $interestPaid = 0;
            $principalPaid = 0;
            
            // 1. Pay penalties
            if ($loan['penalties_balance'] > 0 && $remaining > 0) {
                $penaltiesPaid = min($remaining, $loan['penalties_balance']);
                $remaining -= $penaltiesPaid;
            }
            
            // 2. Pay interest
            if ($loan['interest_balance'] > 0 && $remaining > 0) {
                $interestPaid = min($remaining, $loan['interest_balance']);
                $remaining -= $interestPaid;
            }
            
            // 3. Pay principal
            if ($loan['principal_balance'] > 0 && $remaining > 0) {
                $principalPaid = min($remaining, $loan['principal_balance']);
                $remaining -= $principalPaid;
            }
            
            // Update loan balances
            $newPrincipalBalance = $loan['principal_balance'] - $principalPaid;
            $newInterestBalance = $loan['interest_balance'] - $interestPaid;
            $newPenaltiesBalance = $loan['penalties_balance'] - $penaltiesPaid;
            $newTotalPaid = $loan['total_paid'] + $amount;
            
            $updateData = [
                'principal_balance' => $newPrincipalBalance,
                'interest_balance' => $newInterestBalance,
                'penalties_balance' => $newPenaltiesBalance,
                'total_paid' => $newTotalPaid
            ];
            
            // Close loan if fully paid
            if ($newPrincipalBalance <= 0 && $newInterestBalance <= 0 && $newPenaltiesBalance <= 0) {
                $updateData['status'] = 'closed';
                $updateData['closed_date'] = $paymentDate;
            }
            
            Loan::update($loanId, $updateData);
            
            // Debit member savings
            $newMemberBalance = $member['savings_balance'] - $amount;
            DB::execute("UPDATE members SET savings_balance = ? WHERE id = ?", [$newMemberBalance, $memberId]);
            
            // Ledger entry
            LedgerService::recordTransaction(
                $memberId,
                'loan_repayment',
                0,
                $amount,
                $newMemberBalance,
                "Loan {$loan['loan_number']} repayment. Principal: " . number_format($principalPaid) . 
                ", Interest: " . number_format($interestPaid) . 
                ($penaltiesPaid > 0 ? ", Penalties: " . number_format($penaltiesPaid) : "") .
                ($notes ? ". {$notes}" : ""),
                $userId,
                null,
                $loanId,
                $paymentDate
            );
            
            // Update schedule (mark installments as paid)
            $this->updateSchedulePayments($loanId, $principalPaid, $interestPaid, $paymentDate);
            
            // Add note
            Loan::addNote($loanId, "Payment received: UGX " . number_format($amount) . 
                        " (P: " . number_format($principalPaid) . 
                        ", I: " . number_format($interestPaid) . 
                        ($penaltiesPaid > 0 ? ", Pen: " . number_format($penaltiesPaid) : "") . ")" .
                        ($notes ? ". {$notes}" : ""), 
                        'general', $userId);
            
            // Audit log
            AuditService::log('loan_repayment', 'loans', $loanId, 
                            json_encode(['old_balance' => $loan['principal_balance'] + $loan['interest_balance'] + $loan['penalties_balance']]),
                            json_encode(['amount' => $amount, 'new_balance' => $newPrincipalBalance + $newInterestBalance + $newPenaltiesBalance]),
                            $userId);
            
            DB::commit();
            return true;
            
        } catch (Exception $e) {
            DB::rollback();
            throw $e;
        }
    }
    
    /**
     * Update schedule payments (simplified - marks installments as paid)
     */
    private function updateSchedulePayments($loanId, $principalPaid, $interestPaid, $paymentDate)
    {
        // Get unpaid/partial installments
        $installments = DB::query(
            "SELECT * FROM loan_schedules WHERE loan_id = ? AND status IN ('pending', 'partial', 'overdue') ORDER BY installment_number ASC",
            [$loanId]
        );
        
        $remainingPrincipal = $principalPaid;
        $remainingInterest = $interestPaid;
        
        foreach ($installments as $inst) {
            if ($remainingPrincipal <= 0 && $remainingInterest <= 0) break;
            
            $principalToApply = min($remainingInterest, $inst['interest_due'] - $inst['interest_paid']);
            $interestToApply = min($remainingPrincipal, $inst['principal_due'] - $inst['principal_paid']);
            
            $newInterestPaid = $inst['interest_paid'] + $principalToApply;
            $newPrincipalPaid = $inst['principal_paid'] + $interestToApply;
            $newTotalPaid = $newInterestPaid + $newPrincipalPaid;
            
            $status = 'partial';
            $paidDate = null;
            
            if ($newTotalPaid >= $inst['total_due']) {
                $status = 'paid';
                $paidDate = $paymentDate;
            }
            
            DB::execute(
                "UPDATE loan_schedules SET interest_paid = ?, principal_paid = ?, total_paid = ?, status = ?, paid_date = ? WHERE id = ?",
                [$newInterestPaid, $newPrincipalPaid, $newTotalPaid, $status, $paidDate, $inst['id']]
            );
            
            $remainingInterest -= $principalToApply;
            $remainingPrincipal -= $interestToApply;
        }
    }
    
    /**
     * Calculate loan status and arrears (ONE PLACE for all arrears logic)
     */
    public function calculateLoanStatus($loan)
    {
        $status = [
            'is_current' => true,
            'days_overdue' => 0,
            'arrears_amount' => 0,
            'next_payment_date' => null,
            'next_payment_amount' => 0
        ];
        
        // For migrated loans, use opening_date as reference
        $referenceDate = $loan['is_migrated'] && $loan['opening_date'] 
                        ? $loan['opening_date'] 
                        : $loan['first_payment_date'];
        
        if (!$referenceDate) {
            return $status;
        }
        
        $today = new \DateTime();
        $nextPayment = DB::query(
            "SELECT * FROM loan_schedules WHERE loan_id = ? AND status IN ('pending', 'partial', 'overdue') ORDER BY due_date ASC LIMIT 1",
            [$loan['id']]
        );
        
        if (!empty($nextPayment)) {
            $nextPayment = $nextPayment[0];
            $dueDate = new \DateTime($nextPayment['due_date']);
            
            $status['next_payment_date'] = $nextPayment['due_date'];
            $status['next_payment_amount'] = $nextPayment['total_due'] - $nextPayment['total_paid'];
            
            if ($today > $dueDate) {
                $interval = $today->diff($dueDate);
                $status['days_overdue'] = $interval->days;
                $status['is_current'] = false;
                
                // Calculate arrears (all overdue installments)
                $overdueInstallments = DB::query(
                    "SELECT SUM(total_due - total_paid) as arrears FROM loan_schedules WHERE loan_id = ? AND due_date < CURDATE() AND status != 'paid'",
                    [$loan['id']]
                );
                
                $status['arrears_amount'] = $overdueInstallments[0]['arrears'] ?? 0;
            }
        }
        
        return $status;
    }
    
    /**
     * Add manual charge to loan (MANUAL ONLY - never auto-applied)
     */
    public function addCharge($loanId, $chargeType, $amount, $reason, $userId)
    {
        DB::beginTransaction();
        
        try {
            $loan = Loan::getById($loanId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            // Add charge to loan_charges table
            $sql = "INSERT INTO loan_charges (loan_id, member_id, charge_type, amount, reason, added_by) VALUES (?, ?, ?, ?, ?, ?)";
            DB::execute($sql, [$loanId, $loan['member_id'], $chargeType, $amount, $reason, $userId]);
            
            // Update loan penalties balance
            $newPenaltiesBalance = $loan['penalties_balance'] + $amount;
            Loan::update($loanId, ['penalties_balance' => $newPenaltiesBalance]);
            
            // Add note
            Loan::addNote($loanId, "Charge added: {$chargeType} - UGX " . number_format($amount) . ". Reason: {$reason}", 'general', $userId);
            
            // Audit log
            AuditService::log('loan_charge_added', 'loan_charges', $loanId,
                            json_encode(['old_penalties' => $loan['penalties_balance']]),
                            json_encode(['charge_type' => $chargeType, 'amount' => $amount, 'new_penalties' => $newPenaltiesBalance]),
                            $userId);
            
            DB::commit();
            return true;
            
        } catch (Exception $e) {
            DB::rollback();
            throw $e;
        }
    }
    
    /**
     * Correct loan data (admin only - for migrated loans)
     */
    public function correctLoanData($loanId, $corrections, $reason, $userId)
    {
        DB::beginTransaction();
        
        try {
            $loan = Loan::getById($loanId);
            if (!$loan) {
                throw new Exception("Loan not found");
            }
            
            $oldData = json_encode($loan);
            
            // Update loan
            Loan::update($loanId, $corrections);
            
            // Add note
            Loan::addNote($loanId, "Loan data corrected: {$reason}. Changes: " . json_encode($corrections), 'correction', $userId);
            
            // Audit log
            AuditService::log('loan_data_correction', 'loans', $loanId,
                            $oldData,
                            json_encode($corrections),
                            $userId);
            
            DB::commit();
            return true;
            
        } catch (Exception $e) {
            DB::rollback();
            throw $e;
        }
    }
}
