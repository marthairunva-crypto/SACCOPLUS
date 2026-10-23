<?php

namespace App\Services;

use App\Core\DB;
use Exception;

/**
 * Double-Entry Bookkeeping Service
 * 
 * All financial transactions MUST go through this service.
 * Enforces double-entry: SUM(debit) = SUM(credit) for each entry.
 */
class JournalService
{
    /**
     * Post a journal entry with multiple lines
     * 
     * @param int $saccoId
     * @param int $branchId
     * @param string $txnType (deposit, withdrawal, loan_disbursement, loan_repayment, etc.)
     * @param string $description
     * @param array $lines Each line: ['gl_account_id' => int, 'debit' => decimal, 'credit' => decimal, 'member_account_id' => int|null, 'loan_id' => int|null]
     * @param int $postedBy User ID
     * @param string $valueDate Date in Y-m-d format
     * @param string|null $idempotencyKey For mobile retries
     * @return int Journal entry ID
     * @throws Exception if lines don't balance or other validation fails
     */
    public function postEntry(
        int $saccoId,
        int $branchId,
        string $txnType,
        string $description,
        array $lines,
        int $postedBy,
        string $valueDate = null,
        ?string $idempotencyKey = null
    ): int {
        // Validate lines balance
        $totalDebit = 0;
        $totalCredit = 0;
        
        foreach ($lines as $line) {
            $debit = $line['debit'] ?? 0;
            $credit = $line['credit'] ?? 0;
            
            if ($debit < 0 || $credit < 0) {
                throw new Exception("Debit and credit amounts must be non-negative");
            }
            
            if ($debit > 0 && $credit > 0) {
                throw new Exception("A line cannot have both debit and credit");
            }
            
            $totalDebit += $debit;
            $totalCredit += $credit;
        }
        
        // Must balance to 2 decimal places
        if (abs($totalDebit - $totalCredit) > 0.01) {
            throw new Exception("Journal entry does not balance. Debit: {$totalDebit}, Credit: {$totalCredit}");
        }
        
        if (count($lines) < 2) {
            throw new Exception("Journal entry must have at least 2 lines (double-entry)");
        }
        
        $valueDate = $valueDate ?? date('Y-m-d');
        
        // Check idempotency
        if ($idempotencyKey) {
            $existing = DB::query(
                "SELECT id FROM journal_entries WHERE sacco_id = ? AND idempotency_key = ?",
                [$saccoId, $idempotencyKey]
            );
            
            if (!empty($existing)) {
                // Already posted - return existing entry ID
                return $existing[0]['id'];
            }
        }
        
        DB::beginTransaction();
        
        try {
            // Generate transaction reference
            $txnRef = $this->generateTxnRef($saccoId, $txnType);
            
            // Insert journal entry
            $sql = "
                INSERT INTO journal_entries (
                    sacco_id, branch_id, txn_ref, idempotency_key, txn_type,
                    description, value_date, posted_by
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ";
            
            DB::execute($sql, [
                $saccoId,
                $branchId,
                $txnRef,
                $idempotencyKey,
                $txnType,
                $description,
                $valueDate,
                $postedBy
            ]);
            
            $entryId = DB::lastInsertId();
            
            // Insert journal lines
            foreach ($lines as $line) {
                $lineSql = "
                    INSERT INTO journal_lines (
                        sacco_id, entry_id, gl_account_id, member_account_id,
                        loan_id, debit, credit
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ";
                
                DB::execute($lineSql, [
                    $saccoId,
                    $entryId,
                    $line['gl_account_id'],
                    $line['member_account_id'] ?? null,
                    $line['loan_id'] ?? null,
                    $line['debit'] ?? 0,
                    $line['credit'] ?? 0
                ]);
            }
            
            DB::commit();
            return $entryId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Failed to post journal entry: " . $e->getMessage());
        }
    }
    
    /**
     * Post a reversal entry
     */
    public function reverseEntry(
        int $entryId,
        string $reason,
        int $postedBy
    ): int {
        $entry = DB::query(
            "SELECT * FROM journal_entries WHERE id = ?",
            [$entryId]
        );
        
        if (empty($entry)) {
            throw new Exception("Journal entry not found");
        }
        
        $entry = $entry[0];
        
        // Check if already reversed
        $existingReversal = DB::query(
            "SELECT id FROM journal_entries WHERE reverses_entry_id = ?",
            [$entryId]
        );
        
        if (!empty($existingReversal)) {
            throw new Exception("Entry has already been reversed");
        }
        
        // Get original lines
        $originalLines = DB::query(
            "SELECT * FROM journal_lines WHERE entry_id = ?",
            [$entryId]
        );
        
        // Create reversal lines (swap debit/credit)
        $reversalLines = [];
        foreach ($originalLines as $line) {
            $reversalLines[] = [
                'gl_account_id' => $line['gl_account_id'],
                'member_account_id' => $line['member_account_id'],
                'loan_id' => $line['loan_id'],
                'debit' => $line['credit'],  // Swap
                'credit' => $line['debit']   // Swap
            ];
        }
        
        DB::beginTransaction();
        
        try {
            // Post reversal entry
            $reversalTxnRef = $this->generateTxnRef($entry['sacco_id'], 'reversal');
            
            $sql = "
                INSERT INTO journal_entries (
                    sacco_id, branch_id, txn_ref, txn_type, description,
                    value_date, reverses_entry_id, posted_by
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ";
            
            DB::execute($sql, [
                $entry['sacco_id'],
                $entry['branch_id'],
                $reversalTxnRef,
                'reversal',
                "REVERSAL: {$entry['description']}. Reason: {$reason}",
                date('Y-m-d'),
                $entryId,
                $postedBy
            ]);
            
            $reversalId = DB::lastInsertId();
            
            // Insert reversal lines
            foreach ($reversalLines as $line) {
                $lineSql = "
                    INSERT INTO journal_lines (
                        sacco_id, entry_id, gl_account_id, member_account_id,
                        loan_id, debit, credit
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ";
                
                DB::execute($lineSql, [
                    $entry['sacco_id'],
                    $reversalId,
                    $line['gl_account_id'],
                    $line['member_account_id'],
                    $line['loan_id'],
                    $line['debit'],
                    $line['credit']
                ]);
            }
            
            // Audit log
            AuditService::log(
                'journal_reversal',
                'journal_entries',
                $reversalId,
                json_encode(['original_entry_id' => $entryId]),
                json_encode(['reason' => $reason]),
                $postedBy,
                $entry['sacco_id']
            );
            
            DB::commit();
            return $reversalId;
            
        } catch (Exception $e) {
            DB::rollback();
            throw new Exception("Failed to reverse entry: " . $e->getMessage());
        }
    }
    
    /**
     * Get member account balance (derived from journal lines)
     */
    public function getMemberAccountBalance(int $saccoId, int $memberAccountId): float
    {
        $sql = "
            SELECT COALESCE(SUM(credit - debit), 0) as balance
            FROM journal_lines
            WHERE sacco_id = ? AND member_account_id = ?
        ";
        
        $result = DB::query($sql, [$saccoId, $memberAccountId]);
        return (float)($result[0]['balance'] ?? 0);
    }
    
    /**
     * Get GL account balance
     */
    public function getGLAccountBalance(int $saccoId, int $glAccountId, ?string $asOfDate = null): float
    {
        if ($asOfDate) {
            $sql = "
                SELECT COALESCE(SUM(debit - credit), 0) as balance
                FROM journal_lines jl
                INNER JOIN journal_entries je ON jl.entry_id = je.id
                WHERE jl.sacco_id = ? AND jl.gl_account_id = ? AND je.value_date <= ?
            ";
            $result = DB::query($sql, [$saccoId, $glAccountId, $asOfDate]);
        } else {
            $sql = "
                SELECT COALESCE(SUM(debit - credit), 0) as balance
                FROM journal_lines
                WHERE sacco_id = ? AND gl_account_id = ?
            ";
            $result = DB::query($sql, [$saccoId, $glAccountId]);
        }
        
        return (float)($result[0]['balance'] ?? 0);
    }
    
    /**
     * Get member account statement (transaction history)
     */
    public function getMemberAccountStatement(
        int $saccoId,
        int $memberAccountId,
        string $startDate,
        string $endDate,
        int $limit = 100,
        int $offset = 0
    ): array {
        $sql = "
            SELECT 
                je.id as entry_id,
                je.txn_ref,
                je.txn_type,
                je.description,
                je.value_date,
                jl.debit,
                jl.credit,
                u.name as posted_by_name
            FROM journal_lines jl
            INNER JOIN journal_entries je ON jl.entry_id = je.id
            LEFT JOIN users u ON je.posted_by = u.id
            WHERE jl.sacco_id = ? 
              AND jl.member_account_id = ?
              AND je.value_date BETWEEN ? AND ?
            ORDER BY je.value_date DESC, je.id DESC
            LIMIT ? OFFSET ?
        ";
        
        return DB::query($sql, [$saccoId, $memberAccountId, $startDate, $endDate, $limit, $offset]);
    }
    
    /**
     * Generate transaction reference
     */
    private function generateTxnRef(int $saccoId, string $txnType): string
    {
        $prefix = strtoupper(substr($txnType, 0, 3));
        $date = date('Ymd');
        
        // Get next sequence for today
        $sql = "
            SELECT COUNT(*) as count 
            FROM journal_entries 
            WHERE sacco_id = ? AND txn_ref LIKE ?
        ";
        
        $result = DB::query($sql, [$saccoId, "{$prefix}{$date}%"]);
        $sequence = ($result[0]['count'] ?? 0) + 1;
        
        return sprintf("%s%s%04d", $prefix, $date, $sequence);
    }
    
    /**
     * Get trial balance (all GL accounts)
     */
    public function getTrialBalance(int $saccoId, ?string $asOfDate = null): array
    {
        $dateCondition = $asOfDate ? "AND je.value_date <= ?" : "";
        $params = $asOfDate ? [$saccoId, $asOfDate] : [$saccoId];
        
        $sql = "
            SELECT 
                gl.id,
                gl.code,
                gl.name,
                gl.type,
                COALESCE(SUM(jl.debit), 0) as total_debit,
                COALESCE(SUM(jl.credit), 0) as total_credit,
                COALESCE(SUM(jl.debit - jl.credit), 0) as balance
            FROM gl_accounts gl
            LEFT JOIN journal_lines jl ON gl.id = jl.gl_account_id AND jl.sacco_id = ?
            LEFT JOIN journal_entries je ON jl.entry_id = je.id
            WHERE gl.sacco_id = ? AND gl.status = 'active'
            {$dateCondition}
            GROUP BY gl.id, gl.code, gl.name, gl.type
            ORDER BY gl.code
        ";
        
        // Adjust params for the query structure
        $queryParams = [$saccoId, $saccoId];
        if ($asOfDate) {
            $queryParams[] = $asOfDate;
        }
        
        return DB::query($sql, $queryParams);
    }
}
