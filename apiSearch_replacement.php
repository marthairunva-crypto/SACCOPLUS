<?php
// ============================================================================
// REPLACEMENT FOR MembersController::apiSearch()
// Copy this entire method and replace the existing apiSearch() in MembersController.php
// ============================================================================

public function apiSearch() {
    header('Content-Type: application/json');
    
    $query = $_GET['q'] ?? '';
    
    if (strlen($query) < 2) {
        echo json_encode(['success' => true, 'members' => [], 'count' => 0]);
        return;
    }
    
    $db = DB::connect();
    $search = "%{$query}%";
    
    try {
        $stmt = $db->prepare("
            SELECT 
                m.id,
                m.member_no,
                COALESCE(m.full_name, m.name) as name,
                m.phone,
                m.email,
                m.status
            FROM members m
            WHERE (
                COALESCE(m.full_name, m.name) LIKE :search
                OR m.member_no LIKE :search
                OR m.phone LIKE :search
                OR m.email LIKE :search
            )
            AND m.status != 'deleted'
            ORDER BY 
                CASE 
                    WHEN m.member_no LIKE :search THEN 1
                    WHEN COALESCE(m.full_name, m.name) LIKE :search THEN 2
                    ELSE 3
                END,
                m.member_no ASC
            LIMIT 20
        ");
        
        $stmt->execute(['search' => $search]);
        $members = $stmt->fetchAll();
        
        echo json_encode([
            'success' => true,
            'members' => $members,
            'count' => count($members)
        ]);
        
    } catch (\Exception $e) {
        error_log("Member search error: " . $e->getMessage());
        echo json_encode([
            'success' => false,
            'error' => 'Search failed',
            'members' => [],
            'count' => 0
        ]);
    }
}

// ============================================================================
// HOW TO APPLY THIS FIX:
// ============================================================================
// 1. Open C:\xampp\htdocs\saccoplus-php\app\Controllers\MembersController.php
// 2. Find the method: public function apiSearch()
// 3. Delete the ENTIRE existing apiSearch() method from "public function apiSearch() {" to its closing "}"
// 4. Copy the replacement method above (starting from "public function apiSearch()") and paste it
// 5. Save the file
// 6. Test by searching for a member in the notifications page
