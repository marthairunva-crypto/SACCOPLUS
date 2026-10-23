<?php

namespace App\Models;

use App\Core\DB;
use PDO;

class Member
{
    /**
     * Get all members for a SACCO
     */
    public static function getAll($saccoId, $filters = [])
    {
        $where = ['m.sacco_id = ?'];
        $params = [$saccoId];
        
        if (!empty($filters['status'])) {
            $where[] = 'm.status = ?';
            $params[] = $filters['status'];
        }
        
        if (!empty($filters['branch_id'])) {
            $where[] = 'm.branch_id = ?';
            $params[] = $filters['branch_id'];
        }
        
        if (!empty($filters['search'])) {
            $where[] = '(m.full_name LIKE ? OR m.member_no LIKE ? OR m.phone LIKE ? OR m.national_id LIKE ?)';
            $search = '%' . $filters['search'] . '%';
            $params[] = $search;
            $params[] = $search;
            $params[] = $search;
            $params[] = $search;
        }
        
        $whereClause = implode(' AND ', $where);
        
        $sql = "
            SELECT m.*,
                   b.name as branch_name,
                   -- Get savings balance (derived from journal)
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = m.id AND ma.type = 'savings' AND jl.sacco_id = ?
                   ), 0) as savings_balance,
                   -- Get shares balance
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = m.id AND ma.type = 'shares' AND jl.sacco_id = ?
                   ), 0) as shares_balance
            FROM members m
            INNER JOIN branches b ON m.branch_id = b.id
            WHERE {$whereClause}
            ORDER BY m.created_at DESC
        ";
        
        // Add sacco_id for subqueries
        $params[] = $saccoId;
        $params[] = $saccoId;
        
        return DB::query($sql, $params);
    }
    
    /**
     * Get member by ID with balances
     */
    public static function getById($id, $saccoId = null)
    {
        $sql = "
            SELECT m.*,
                   b.name as branch_name,
                   b.code as branch_code,
                   -- Savings balance
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = m.id AND ma.type = 'savings'
                   ), 0) as savings_balance,
                   -- Shares balance
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = m.id AND ma.type = 'shares'
                   ), 0) as shares_balance,
                   -- Get account numbers
                   (SELECT account_no FROM member_accounts WHERE member_id = m.id AND type = 'savings' LIMIT 1) as savings_account_no,
                   (SELECT account_no FROM member_accounts WHERE member_id = m.id AND type = 'shares' LIMIT 1) as shares_account_no
            FROM members m
            INNER JOIN branches b ON m.branch_id = b.id
            WHERE m.id = ?
        ";
        
        $params = [$id];
        
        if ($saccoId) {
            $sql .= " AND m.sacco_id = ?";
            $params[] = $saccoId;
        }
        
        $result = DB::query($sql, $params);
        return $result[0] ?? null;
    }
    
    /**
     * Search members
     */
    public static function search($saccoId, $query)
    {
        $sql = "
            SELECT m.id, m.member_no, m.full_name, m.phone,
                   COALESCE((
                       SELECT SUM(jl.credit - jl.debit)
                       FROM journal_lines jl
                       INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
                       WHERE ma.member_id = m.id AND ma.type = 'savings'
                   ), 0) as savings_balance
            FROM members m
            WHERE m.sacco_id = ? 
              AND m.status = 'active'
              AND (m.full_name LIKE ? OR m.member_no LIKE ? OR m.phone LIKE ?)
            LIMIT 20
        ";
        
        $search = '%' . $query . '%';
        return DB::query($sql, [$saccoId, $search, $search, $search]);
    }
    
    /**
     * Create new member
     */
    public static function create($data)
    {
        $sql = "
            INSERT INTO members (
                sacco_id, branch_id, member_no, full_name, national_id,
                phone, email, gender, date_of_birth, address,
                next_of_kin_name, next_of_kin_phone, status, joined_on,
                created_by, legacy_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        DB::execute($sql, [
            $data['sacco_id'],
            $data['branch_id'],
            $data['member_no'],
            $data['full_name'],
            $data['national_id'] ?? null,
            $data['phone'] ?? null,
            $data['email'] ?? null,
            $data['gender'] ?? null,
            $data['date_of_birth'] ?? null,
            $data['address'] ?? null,
            $data['next_of_kin_name'] ?? null,
            $data['next_of_kin_phone'] ?? null,
            $data['status'] ?? 'active',
            $data['joined_on'] ?? date('Y-m-d'),
            $data['created_by'] ?? null,
            $data['legacy_id'] ?? null
        ]);
        
        return DB::lastInsertId();
    }
    
    /**
     * Update member
     */
    public static function update($id, $data, $saccoId = null)
    {
        $fields = [];
        $params = [];
        
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $params[] = $value;
        }
        
        $params[] = $id;
        
        $sql = "UPDATE members SET " . implode(', ', $fields) . " WHERE id = ?";
        
        if ($saccoId) {
            $sql .= " AND sacco_id = ?";
            $params[] = $saccoId;
        }
        
        return DB::execute($sql, $params);
    }
    
    /**
     * Get member account by type
     */
    public static function getAccount($memberId, $type = 'savings')
    {
        $sql = "SELECT * FROM member_accounts WHERE member_id = ? AND type = ? LIMIT 1";
        $result = DB::query($sql, [$memberId, $type]);
        return $result[0] ?? null;
    }
    
    /**
     * Create member account (savings or shares)
     */
    public static function createAccount($memberId, $type, $saccoId, $branchId, $glAccountId)
    {
        // Generate account number
        $prefix = $type === 'savings' ? 'SAV' : 'SHR';
        $accountNo = self::generateAccountNumber($saccoId, $prefix);
        
        $sql = "
            INSERT INTO member_accounts (
                sacco_id, branch_id, member_id, account_no, type, gl_account_id, status
            ) VALUES (?, ?, ?, ?, ?, ?, 'active')
        ";
        
        DB::execute($sql, [$saccoId, $branchId, $memberId, $accountNo, $type, $glAccountId]);
        return DB::lastInsertId();
    }
    
    /**
     * Generate next member number
     */
    public static function generateMemberNumber($saccoId)
    {
        $prefix = 'MEM';
        $year = date('Y');
        
        // Get last member number for this year
        $sql = "SELECT member_no FROM members WHERE sacco_id = ? AND member_no LIKE ? ORDER BY id DESC LIMIT 1";
        $result = DB::query($sql, [$saccoId, "{$prefix}{$year}%"]);
        
        if (empty($result)) {
            $sequence = 1;
        } else {
            $lastNumber = $result[0]['member_no'];
            $sequence = (int)substr($lastNumber, -5) + 1;
        }
        
        return sprintf("%s%s%05d", $prefix, $year, $sequence);
    }
    
    /**
     * Generate account number
     */
    private static function generateAccountNumber($saccoId, $prefix)
    {
        $year = date('y');
        
        $sql = "SELECT account_no FROM member_accounts WHERE sacco_id = ? AND account_no LIKE ? ORDER BY id DESC LIMIT 1";
        $result = DB::query($sql, [$saccoId, "{$prefix}{$year}%"]);
        
        if (empty($result)) {
            $sequence = 1;
        } else {
            $lastNumber = $result[0]['account_no'];
            $sequence = (int)substr($lastNumber, -6) + 1;
        }
        
        return sprintf("%s%s%06d", $prefix, $year, $sequence);
    }
    
    /**
     * Get member transaction summary
     */
    public static function getTransactionSummary($memberId, $days = 30)
    {
        $sql = "
            SELECT 
                je.txn_type,
                COUNT(*) as count,
                SUM(jl.debit) as total_debit,
                SUM(jl.credit) as total_credit
            FROM journal_lines jl
            INNER JOIN journal_entries je ON jl.entry_id = je.id
            INNER JOIN member_accounts ma ON jl.member_account_id = ma.id
            WHERE ma.member_id = ?
              AND je.value_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
            GROUP BY je.txn_type
            ORDER BY je.txn_type
        ";
        
        return DB::query($sql, [$memberId, $days]);
    }
}
