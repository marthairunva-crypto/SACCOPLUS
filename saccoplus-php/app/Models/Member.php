<?php
declare(strict_types=1);

namespace App\Models;

use App\Core\DB;
use PDO;

class Member
{
    /**
     * Get all members for a SACCO with pagination
     */
    public static function getAll(int $saccoId, int $limit = 50, int $offset = 0): array
    {
        $stmt = DB::prepare("
            SELECT id, account_number, membership_number, full_name, phone, 
                   savings_balance, shares_balance, status, joined_date
            FROM members
            WHERE sacco_id = :sacco_id
            ORDER BY full_name ASC
            LIMIT :limit OFFSET :offset
        ");
        $stmt->bindValue(':sacco_id', $saccoId, PDO::PARAM_INT);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Count total members for pagination
     */
    public static function count(int $saccoId): int
    {
        $stmt = DB::prepare("SELECT COUNT(*) FROM members WHERE sacco_id = :sacco_id");
        $stmt->execute([':sacco_id' => $saccoId]);
        return (int) $stmt->fetchColumn();
    }

    /**
     * Get member by ID
     */
    public static function getById(int $id, int $saccoId): ?array
    {
        $stmt = DB::prepare("
            SELECT *
            FROM members
            WHERE id = :id AND sacco_id = :sacco_id
        ");
        $stmt->execute([':id' => $id, ':sacco_id' => $saccoId]);
        $member = $stmt->fetch(PDO::FETCH_ASSOC);
        return $member ?: null;
    }

    /**
     * Search members by name, account number, or phone
     */
    public static function search(int $saccoId, string $query, int $limit = 20): array
    {
        $search = "%{$query}%";
        $stmt = DB::prepare("
            SELECT id, account_number, full_name, phone, savings_balance, status
            FROM members
            WHERE sacco_id = :sacco_id
              AND (full_name LIKE :search 
                   OR account_number LIKE :search 
                   OR phone LIKE :search)
            ORDER BY full_name ASC
            LIMIT :limit
        ");
        $stmt->bindValue(':sacco_id', $saccoId, PDO::PARAM_INT);
        $stmt->bindValue(':search', $search, PDO::PARAM_STR);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
