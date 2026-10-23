<?php

namespace App\Models;

use App\Core\DB;
use PDO;

class Loan
{
    /**
     * Get all loans with member info
     */
    public static function getAll($filters = [])
    {
        $where = ['1=1'];
        $params = [];
        
        if (!empty($filters['status'])) {
            $where[] = 'l.status = ?';
            $params[] = $filters['status'];
        }
        
        if (!empty($filters['member_id'])) {
            $where[] = 'l.member_id = ?';
            $params[] = $filters['member_id'];
        }
        
        if (!empty($filters['search'])) {
            $where[] = '(l.loan_number LIKE ? OR m.name LIKE ? OR m.account_number LIKE ?)';
            $search = '%' . $filters['search'] . '%';
            $params[] = $search;
            $params[] = $search;
            $params[] = $search;
        }
        
        $whereClause = implode(' AND ', $where);
        
        $sql = "
            SELECT l.*, 
                   m.name as member_name,
                   m.account_number,
                   m.phone,
                   (l.principal_balance + l.interest_balance + l.penalties_balance) as total_balance
            FROM loans l
            INNER JOIN members m ON l.member_id = m.id
            WHERE {$whereClause}
            ORDER BY l.created_at DESC
        ";
        
        return DB::query($sql, $params);
    }
    
    /**
     * Get loan by ID with member info
     */
    public static function getById($id)
    {
        $sql = "
            SELECT l.*, 
                   m.name as member_name,
                   m.account_number,
                   m.phone,
                   m.email,
                   m.national_id,
                   g1.name as guarantor_1_name,
                   g1.phone as guarantor_1_phone,
                   g2.name as guarantor_2_name,
                   g2.phone as guarantor_2_phone,
                   creator.username as applied_by_name,
                   approver.username as approved_by_name,
                   disburser.username as disbursed_by_name,
                   (l.principal_balance + l.interest_balance + l.penalties_balance) as total_balance
            FROM loans l
            INNER JOIN members m ON l.member_id = m.id
            LEFT JOIN members g1 ON l.guarantor_1_id = g1.id
            LEFT JOIN members g2 ON l.guarantor_2_id = g2.id
            LEFT JOIN users creator ON l.applied_by = creator.id
            LEFT JOIN users approver ON l.approved_by = approver.id
            LEFT JOIN users disburser ON l.disbursed_by = disburser.id
            WHERE l.id = ?
        ";
        
        $result = DB::query($sql, [$id]);
        return $result[0] ?? null;
    }
    
    /**
     * Get loan by loan number
     */
    public static function getByLoanNumber($loanNumber)
    {
        $sql = "SELECT * FROM loans WHERE loan_number = ?";
        $result = DB::query($sql, [$loanNumber]);
        return $result[0] ?? null;
    }
    
    /**
     * Create loan application
     */
    public static function create($data)
    {
        $sql = "
            INSERT INTO loans (
                loan_number, member_id, loan_type, purpose,
                amount_requested, amount_approved, interest_rate, term_months,
                repayment_frequency, application_date, applied_by,
                guarantor_1_id, guarantor_1_amount, guarantor_2_id, guarantor_2_amount,
                collateral_type, collateral_value, collateral_description
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ";
        
        DB::execute($sql, [
            $data['loan_number'],
            $data['member_id'],
            $data['loan_type'],
            $data['purpose'] ?? null,
            $data['amount_requested'],
            $data['amount_approved'],
            $data['interest_rate'],
            $data['term_months'],
            $data['repayment_frequency'] ?? 'monthly',
            $data['application_date'],
            $data['applied_by'],
            $data['guarantor_1_id'] ?? null,
            $data['guarantor_1_amount'] ?? null,
            $data['guarantor_2_id'] ?? null,
            $data['guarantor_2_amount'] ?? null,
            $data['collateral_type'] ?? null,
            $data['collateral_value'] ?? null,
            $data['collateral_description'] ?? null,
        ]);
        
        return DB::lastInsertId();
    }
    
    /**
     * Update loan
     */
    public static function update($id, $data)
    {
        $fields = [];
        $params = [];
        
        foreach ($data as $key => $value) {
            $fields[] = "{$key} = ?";
            $params[] = $value;
        }
        
        $params[] = $id;
        
        $sql = "UPDATE loans SET " . implode(', ', $fields) . " WHERE id = ?";
        return DB::execute($sql, $params);
    }
    
    /**
     * Get loan schedule
     */
    public static function getSchedule($loanId)
    {
        $sql = "
            SELECT *
            FROM loan_schedules
            WHERE loan_id = ?
            ORDER BY installment_number ASC
        ";
        
        return DB::query($sql, [$loanId]);
    }
    
    /**
     * Get loan charges
     */
    public static function getCharges($loanId)
    {
        $sql = "
            SELECT lc.*,
                   u.username as added_by_name,
                   w.username as waived_by_name
            FROM loan_charges lc
            LEFT JOIN users u ON lc.added_by = u.id
            LEFT JOIN users w ON lc.waived_by = w.id
            WHERE lc.loan_id = ?
            ORDER BY lc.created_at DESC
        ";
        
        return DB::query($sql, [$loanId]);
    }
    
    /**
     * Get loan notes
     */
    public static function getNotes($loanId)
    {
        $sql = "
            SELECT ln.*,
                   u.username as created_by_name
            FROM loan_notes ln
            LEFT JOIN users u ON ln.created_by = u.id
            WHERE ln.loan_id = ?
            ORDER BY ln.created_at DESC
        ";
        
        return DB::query($sql, [$loanId]);
    }
    
    /**
     * Add note to loan
     */
    public static function addNote($loanId, $note, $noteType, $createdBy)
    {
        $sql = "INSERT INTO loan_notes (loan_id, note, note_type, created_by) VALUES (?, ?, ?, ?)";
        return DB::execute($sql, [$loanId, $note, $noteType, $createdBy]);
    }
    
    /**
     * Get active loans count by member
     */
    public static function getActiveLoansByMember($memberId)
    {
        $sql = "SELECT COUNT(*) as count FROM loans WHERE member_id = ? AND status IN ('active', 'disbursed')";
        $result = DB::query($sql, [$memberId]);
        return $result[0]['count'] ?? 0;
    }
    
    /**
     * Get total outstanding by member
     */
    public static function getTotalOutstandingByMember($memberId)
    {
        $sql = "
            SELECT SUM(principal_balance + interest_balance + penalties_balance) as total
            FROM loans
            WHERE member_id = ? AND status IN ('active', 'disbursed')
        ";
        $result = DB::query($sql, [$memberId]);
        return $result[0]['total'] ?? 0;
    }
    
    /**
     * Generate next loan number
     */
    public static function generateLoanNumber()
    {
        $prefix = 'LN';
        $year = date('Y');
        $month = date('m');
        
        // Get last loan number for this month
        $sql = "SELECT loan_number FROM loans WHERE loan_number LIKE ? ORDER BY id DESC LIMIT 1";
        $result = DB::query($sql, ["{$prefix}{$year}{$month}%"]);
        
        if (empty($result)) {
            $sequence = 1;
        } else {
            $lastNumber = $result[0]['loan_number'];
            $sequence = (int)substr($lastNumber, -4) + 1;
        }
        
        return sprintf("%s%s%s%04d", $prefix, $year, $month, $sequence);
    }
}
