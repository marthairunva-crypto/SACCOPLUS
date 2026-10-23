<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\DB;

class AuditService
{
    /**
     * Log an action to audit trail
     */
    public static function log(
        string $action,
        ?string $entity = null,
        ?string $entityId = null,
        ?array $oldValues = null,
        ?array $newValues = null,
        ?int $userId = null
    ): void {
        try {
            $stmt = DB::prepare("
                INSERT INTO audit_log (
                    sacco_id, user_id, action, entity, entity_id, 
                    old_values, new_values, ip
                ) VALUES (
                    :sacco_id, :user_id, :action, :entity, :entity_id,
                    :old_values, :new_values, :ip
                )
            ");
            
            // Get SACCO ID from session if user is logged in
            $saccoId = null;
            if ($userId) {
                $userStmt = DB::prepare("SELECT sacco_id FROM users WHERE id = :id");
                $userStmt->execute([':id' => $userId]);
                $saccoId = $userStmt->fetchColumn() ?: null;
            }
            
            $stmt->execute([
                ':sacco_id' => $saccoId,
                ':user_id' => $userId,
                ':action' => $action,
                ':entity' => $entity,
                ':entity_id' => $entityId,
                ':old_values' => $oldValues ? json_encode($oldValues) : null,
                ':new_values' => $newValues ? json_encode($newValues) : null,
                ':ip' => $_SERVER['REMOTE_ADDR'] ?? null,
            ]);
        } catch (\Exception $e) {
            // Silent fail - audit logging should not break operations
            error_log("Audit log error: " . $e->getMessage());
        }
    }
}
