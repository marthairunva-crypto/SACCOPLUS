<?php

namespace App\Services;

use App\Core\DB;

class LedgerService
{
    /**
     * Record a transaction in the ledger
     * 
     * @param int $memberId
     * @param string $type (deposit, withdrawal, loan_disbursement, loan_repayment, bank_transfer_in, bank_transfer_out, etc.)
     * @param int $debit Amount debited (money IN - increases balance)
     * @param int $credit Amount credited (money OUT - decreases balance)
     * @param int $balance New balance after transaction
     * @param string $description
     * @param int $userId User who performed the transaction
     * @param string|null $reference External reference (receipt number, etc.)
     * @param int|null $loanId Related loan ID if applicable
     * @param string|null $transactionDate Override transaction date (for backdating)
     */
    public static function recordTransaction(
        $memberId,
        $type,
        $debit,
        $credit,
        $balance,
        $description,
        $userId,
        $reference = null,
        $loanId = null,
        $transactionDate = null
    ) {
        $sql = "
            INSERT INTO ledger (
                member_id, type, debit, credit, balance, 
                description, user_id, reference, loan_id, transaction_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        return DB::execute($sql, [
            $memberId,
            $type,
            $debit,
            $credit,
            $balance,
            $description,
            $userId,
            $reference,
            $loanId,
            $transactionDate ?? date('Y-m-d H:i:s')
        ]);
    }
    
    /**
     * Get member transaction history
     */
    public static function getMemberTransactions($memberId, $limit = 100, $offset = 0)
    {
        $sql = "
            SELECT l.*, u.username as performed_by
            FROM ledger l
            LEFT JOIN users u ON l.user_id = u.id
            WHERE l.member_id = ?
            ORDER BY l.transaction_date DESC, l.id DESC
            LIMIT ? OFFSET ?
        ";
        
        return DB::query($sql, [$memberId, $limit, $offset]);
    }
    
    /**
     * Get transactions for a date range
     */
    public static function getTransactionsByDateRange($startDate, $endDate, $type = null)
    {
        $sql = "
            SELECT l.*, m.name as member_name, m.account_number, u.username as performed_by
            FROM ledger l
            INNER JOIN members m ON l.member_id = m.id
            LEFT JOIN users u ON l.user_id = u.id
            WHERE DATE(l.transaction_date) BETWEEN ? AND ?
        ";
        
        $params = [$startDate, $endDate];
        
        if ($type) {
            $sql .= " AND l.type = ?";
            $params[] = $type;
        }
        
        $sql .= " ORDER BY l.transaction_date DESC";
        
        return DB::query($sql, $params);
    }
    
    /**
     * Get daily summary for teller
     */
    public static function getDailySummary($date, $userId = null)
    {
        $sql = "
            SELECT 
                type,
                COUNT(*) as count,
                SUM(debit) as total_debit,
                SUM(credit) as total_credit
            FROM ledger
            WHERE DATE(transaction_date) = ?
        ";
        
        $params = [$date];
        
        if ($userId) {
            $sql .= " AND user_id = ?";
            $params[] = $userId;
        }
        
        $sql .= " GROUP BY type ORDER BY type";
        
        return DB::query($sql, $params);
    }
}
