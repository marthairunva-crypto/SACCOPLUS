<?php

namespace App\Core;

use App\Core\DB;

/**
 * Context - provides sacco_id and branch_id for current user session
 */
class Context
{
    private static $sacco = null;
    private static $branch = null;
    
    /**
     * Get current SACCO ID from session
     */
    public static function saccoId(): ?int
    {
        if (self::$sacco !== null) {
            return self::$sacco;
        }
        
        $user = Auth::user();
        if (!$user) {
            return null;
        }
        
        self::$sacco = $user['sacco_id'] ?? null;
        return self::$sacco;
    }
    
    /**
     * Get current branch ID from session
     */
    public static function branchId(): ?int
    {
        if (self::$branch !== null) {
            return self::$branch;
        }
        
        $user = Auth::user();
        if (!$user) {
            return null;
        }
        
        // If user has a specific branch, use it
        if ($user['branch_id']) {
            self::$branch = $user['branch_id'];
            return self::$branch;
        }
        
        // Otherwise use head office
        $sacco_id = self::saccoId();
        if ($sacco_id) {
            $result = DB::query(
                "SELECT id FROM branches WHERE sacco_id = ? AND is_head_office = 1 LIMIT 1",
                [$sacco_id]
            );
            
            if (!empty($result)) {
                self::$branch = $result[0]['id'];
                return self::$branch;
            }
        }
        
        return null;
    }
    
    /**
     * Require sacco context (throw exception if not available)
     */
    public static function requireSacco(): int
    {
        $sacco = self::saccoId();
        if (!$sacco) {
            throw new \Exception("SACCO context required");
        }
        return $sacco;
    }
    
    /**
     * Require branch context
     */
    public static function requireBranch(): int
    {
        $branch = self::branchId();
        if (!$branch) {
            throw new \Exception("Branch context required");
        }
        return $branch;
    }
    
    /**
     * Get GL account ID by code
     */
    public static function getGLAccount(string $code): ?int
    {
        $saccoId = self::saccoId();
        if (!$saccoId) {
            return null;
        }
        
        $result = DB::query(
            "SELECT id FROM gl_accounts WHERE sacco_id = ? AND code = ? LIMIT 1",
            [$saccoId, $code]
        );
        
        return $result[0]['id'] ?? null;
    }
}
