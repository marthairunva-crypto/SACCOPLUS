<?php
// Test member search API
$q = 'ain';

// Connect to database
$mysqli = new mysqli('localhost', 'root', '', 'saccoplus_v2');

$search = "%{$q}%";
$stmt = $mysqli->prepare("
    SELECT 
        m.id,
        m.member_no,
        COALESCE(m.full_name, m.name) as name,
        m.phone,
        m.email,
        m.status
    FROM members m
    WHERE (
        COALESCE(m.full_name, m.name) LIKE ?
        OR m.member_no LIKE ?
        OR m.phone LIKE ?
        OR m.email LIKE ?
    )
    AND m.status != 'deleted'
    LIMIT 20
");

$stmt->bind_param('ssss', $search, $search, $search, $search);
$stmt->execute();
$result = $stmt->get_result();

$members = [];
while ($row = $result->fetch_assoc()) {
    $members[] = $row;
}

echo json_encode([
    'success' => true,
    'members' => $members,
    'count' => count($members),
    'query' => $q
], JSON_PRETTY_PRINT);
