<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\DB;
use App\Services\AuditService;
use PDO;
use Exception;

class TellerService
{
    /**
     * Record a deposit transaction
     * Uses DB transaction with row lock to ensure balance accuracy
     */
    public static function deposit(
        int $memberId,
        int $amount,
        string $paymentMethod,
        ?string $referenceNo,
        string $notes,
        int $recordedBy,
        string $transactionDate
    ): array {
        if ($amount <= 0) {
            return ['success' => false, 'message' => 'Amount must be greater than zero'];
        }

        $pdo = DB::connection();
        
        try {
            $pdo->beginTransaction();
            
            // Lock member row for update
            $stmt = $pdo->prepare("
                SELECT id, sacco_id, full_name, savings_balance 
                FROM members 
                WHERE id = :id 
                FOR UPDATE
            ");
            $stmt->execute([':id' => $memberId]);
            $member = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$member) {
                $pdo->rollBack();
                return ['success' => false, 'message' => 'Member not found'];
            }
            
            // Insert ledger entry (credit = money in)
            $stmt = $pdo->prepare("
                INSERT INTO ledger (
                    sacco_id, member_id, type, description, 
                    debit, credit, reference_no, recorded_by, transaction_date
                ) VALUES (
                    :sacco_id, :member_id, 'deposit', :description,
                    0, :amount, :reference_no, :recorded_by, :transaction_date
                )
            ");
            $stmt->execute([
                ':sacco_id' => $member['sacco_id'],
                ':member_id' => $memberId,
                ':description' => "Deposit via {$paymentMethod}" . ($notes ? " - {$notes}" : ""),
                ':amount' => $amount,
                ':reference_no' => $referenceNo,
                ':recorded_by' => $recordedBy,
                ':transaction_date' => $transactionDate,
            ]);
            
            $ledgerId = $pdo->lastInsertId();
            
            // Update member balance (cached)
            $newBalance = $member['savings_balance'] + $amount;
            $stmt = $pdo->prepare("
                UPDATE members 
                SET savings_balance = :balance 
                WHERE id = :id
            ");
            $stmt->execute([':balance' => $newBalance, ':id' => $memberId]);
            
            $pdo->commit();
            
            // Audit log
            AuditService::log(
                'DEPOSIT',
                'ledger',
                (string)$ledgerId,
                null,
                [
                    'member_id' => $memberId,
                    'member_name' => $member['full_name'],
                    'amount' => $amount,
                    'method' => $paymentMethod,
                    'new_balance' => $newBalance,
                ],
                $recordedBy
            );
            
            return [
                'success' => true,
                'message' => 'Deposit recorded successfully',
                'new_balance' => $newBalance,
                'ledger_id' => $ledgerId,
            ];
            
        } catch (Exception $e) {
            $pdo->rollBack();
            error_log("Deposit error: " . $e->getMessage());
            return ['success' => false, 'message' => 'Transaction failed: ' . $e->getMessage()];
        }
    }

    /**
     * Record a withdrawal transaction
     */
    public static function withdraw(
        int $memberId,
        int $amount,
        string $destination,
        ?string $referenceNo,
        string $notes,
        int $recordedBy,
        string $transactionDate
    ): array {
        if ($amount <= 0) {
            return ['success' => false, 'message' => 'Amount must be greater than zero'];
        }

        $pdo = DB::connection();
        
        try {
            $pdo->beginTransaction();
            
            // Lock member row
            $stmt = $pdo->prepare("
                SELECT id, sacco_id, full_name, savings_balance 
                FROM members 
                WHERE id = :id 
                FOR UPDATE
            ");
            $stmt->execute([':id' => $memberId]);
            $member = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$member) {
                $pdo->rollBack();
                return ['success' => false, 'message' => 'Member not found'];
            }
            
            // Check sufficient balance
            if ($member['savings_balance'] < $amount) {
                $pdo->rollBack();
                return [
                    'success' => false, 
                    'message' => 'Insufficient balance. Available: UGX ' . number_format($member['savings_balance'])
                ];
            }
            
            // Insert ledger entry (debit = money out)
            $stmt = $pdo->prepare("
                INSERT INTO ledger (
                    sacco_id, member_id, type, description, 
                    debit, credit, reference_no, recorded_by, transaction_date
                ) VALUES (
                    :sacco_id, :member_id, 'withdrawal', :description,
                    :amount, 0, :reference_no, :recorded_by, :transaction_date
                )
            ");
            $stmt->execute([
                ':sacco_id' => $member['sacco_id'],
                ':member_id' => $memberId,
                ':description' => "Withdrawal to {$destination}" . ($notes ? " - {$notes}" : ""),
                ':amount' => $amount,
                ':reference_no' => $referenceNo,
                ':recorded_by' => $recordedBy,
                ':transaction_date' => $transactionDate,
            ]);
            
            $ledgerId = $pdo->lastInsertId();
            
            // Update member balance
            $newBalance = $member['savings_balance'] - $amount;
            $stmt = $pdo->prepare("
                UPDATE members 
                SET savings_balance = :balance 
                WHERE id = :id
            ");
            $stmt->execute([':balance' => $newBalance, ':id' => $memberId]);
            
            $pdo->commit();
            
            // Audit log
            AuditService::log(
                'WITHDRAWAL',
                'ledger',
                (string)$ledgerId,
                null,
                [
                    'member_id' => $memberId,
                    'member_name' => $member['full_name'],
                    'amount' => $amount,
                    'destination' => $destination,
                    'new_balance' => $newBalance,
                ],
                $recordedBy
            );
            
            return [
                'success' => true,
                'message' => 'Withdrawal recorded successfully',
                'new_balance' => $newBalance,
                'ledger_id' => $ledgerId,
            ];
            
        } catch (Exception $e) {
            $pdo->rollBack();
            error_log("Withdrawal error: " . $e->getMessage());
            return ['success' => false, 'message' => 'Transaction failed: ' . $e->getMessage()];
        }
    }

    /**
     * Get today's teller summary
     */
    public static function getDailySummary(int $saccoId, int $tellerId, string $date): array
    {
        $stmt = DB::prepare("
            SELECT 
                COUNT(*) as transaction_count,
                SUM(CASE WHEN type = 'deposit' THEN credit ELSE 0 END) as total_deposits,
                SUM(CASE WHEN type = 'withdrawal' THEN debit ELSE 0 END) as total_withdrawals,
                SUM(credit - debit) as net_cash_flow
            FROM ledger
            WHERE sacco_id = :sacco_id
              AND recorded_by = :teller_id
              AND transaction_date = :date
              AND type IN ('deposit', 'withdrawal')
        ");
        $stmt->execute([
            ':sacco_id' => $saccoId,
            ':teller_id' => $tellerId,
            ':date' => $date,
        ]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: [
            'transaction_count' => 0,
            'total_deposits' => 0,
            'total_withdrawals' => 0,
            'net_cash_flow' => 0,
        ];
    }

    /**
     * Get recent transactions for teller dashboard
     */
    public static function getRecentTransactions(int $saccoId, int $tellerId, int $limit = 20): array
    {
        $stmt = DB::prepare("
            SELECT l.*, m.full_name as member_name, m.account_number
            FROM ledger l
            JOIN members m ON l.member_id = m.id
            WHERE l.sacco_id = :sacco_id
              AND l.recorded_by = :teller_id
              AND l.type IN ('deposit', 'withdrawal')
            ORDER BY l.created_at DESC
            LIMIT :limit
        ");
        $stmt->bindValue(':sacco_id', $saccoId, PDO::PARAM_INT);
        $stmt->bindValue(':teller_id', $tellerId, PDO::PARAM_INT);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
