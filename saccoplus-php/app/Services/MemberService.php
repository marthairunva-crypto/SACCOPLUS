<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\DB;
use PDO;

class MemberService
{
    /**
     * Get member with calculated summary (loans, recent transactions)
     */
    public static function getMemberSummary(int $memberId, int $saccoId): ?array
    {
        // Get basic member info
        $stmt = DB::prepare("
            SELECT *
            FROM members
            WHERE id = :id AND sacco_id = :sacco_id
        ");
        $stmt->execute([':id' => $memberId, ':sacco_id' => $saccoId]);
        $member = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$member) {
            return null;
        }

        // Get recent transactions (last 5)
        $stmt = DB::prepare("
            SELECT type, description, debit, credit, transaction_date, reference_no
            FROM ledger
            WHERE member_id = :member_id
            ORDER BY transaction_date DESC, id DESC
            LIMIT 5
        ");
        $stmt->execute([':member_id' => $memberId]);
        $member['recent_transactions'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // TODO: Add loan summary when loans table exists
        $member['active_loans'] = 0;
        $member['total_loan_balance'] = 0;

        return $member;
    }

    /**
     * Get member transaction history for statement
     */
    public static function getTransactionHistory(
        int $memberId,
        ?string $fromDate = null,
        ?string $toDate = null
    ): array {
        $sql = "
            SELECT type, description, debit, credit, transaction_date, 
                   reference_no, created_at
            FROM ledger
            WHERE member_id = :member_id
        ";
        
        $params = [':member_id' => $memberId];
        
        if ($fromDate) {
            $sql .= " AND transaction_date >= :from_date";
            $params[':from_date'] = $fromDate;
        }
        
        if ($toDate) {
            $sql .= " AND transaction_date <= :to_date";
            $params[':to_date'] = $toDate;
        }
        
        $sql .= " ORDER BY transaction_date ASC, id ASC";
        
        $stmt = DB::prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
