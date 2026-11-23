<?php
// Create Super Admin user properly with pin_hash
$pdo = new PDO('mysql:host=localhost;dbname=saccoplus_v2;charset=utf8mb4', 'root', '');
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$name = 'Moses Nsubuga';
$phone = '0778474686';
$email = 'moses@saccoplus.com';
$pin = '1234';
$pinHash = password_hash($pin, PASSWORD_BCRYPT);

echo "Creating super admin user...\n";
echo "Phone: $phone\n";
echo "PIN: $pin\n";
echo "PIN Hash: $pinHash\n\n";

try {
    // Check if user already exists
    $stmt = $pdo->prepare("SELECT id FROM users WHERE phone = ? OR email = ?");
    $stmt->execute([$phone, $email]);
    if ($stmt->fetch()) {
        echo "User already exists! Updating instead...\n";
        $stmt = $pdo->prepare("
            UPDATE users 
            SET name = ?, pin_hash = ?, role = 'super_admin', sacco_id = NULL, status = 'active'
            WHERE phone = ? OR email = ?
        ");
        $stmt->execute([$name, $pinHash, $phone, $email]);
        echo "Updated existing user.\n";
    } else {
        // Insert new super admin
        $stmt = $pdo->prepare("
            INSERT INTO users (sacco_id, branch_id, name, email, phone, password_hash, pin_hash, role, member_id, status, created_at)
            VALUES (NULL, NULL, ?, ?, ?, '', ?, 'super_admin', NULL, 'active', NOW())
        ");
        $stmt->execute([$name, $email, $phone, $pinHash]);
        echo "Created new super admin user with ID: " . $pdo->lastInsertId() . "\n";
    }
    
    // Verify the user
    $stmt = $pdo->prepare("SELECT id, name, email, phone, role, pin_hash FROM users WHERE phone = ?");
    $stmt->execute([$phone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user) {
        echo "\n✓ Super Admin Created Successfully!\n\n";
        echo "Details:\n";
        echo "  ID: {$user['id']}\n";
        echo "  Name: {$user['name']}\n";
        echo "  Phone: {$user['phone']}\n";
        echo "  Email: {$user['email']}\n";
        echo "  Role: {$user['role']}\n";
        echo "  Has pin_hash: " . (!empty($user['pin_hash']) ? 'YES' : 'NO') . "\n";
        
        // Test verification
        $verify = password_verify($pin, $user['pin_hash']);
        echo "\n  PIN Verification: " . ($verify ? '✓ SUCCESS' : '✗ FAILED') . "\n";
        
        echo "\n\nLogin Credentials:\n";
        echo "  Phone: $phone\n";
        echo "  PIN: $pin\n";
    }
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
