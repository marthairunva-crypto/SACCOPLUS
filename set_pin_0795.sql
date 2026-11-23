UPDATE members 
SET pin_hash = '$2y$10$nggz3YE8kRG0GwNT2yxwxOlR1bQlk7ZC3QqlibTBtln5i1tyuLyQO'
WHERE phone = '256795551296';

SELECT member_no, COALESCE(full_name, name) as name, phone, LEFT(pin_hash, 30) as pin_preview
FROM members 
WHERE phone = '256795551296';
