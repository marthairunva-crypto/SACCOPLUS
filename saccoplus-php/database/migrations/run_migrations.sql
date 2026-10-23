-- Run all migrations and setup
-- Usage: mysql -u root -p < database/migrations/run_migrations.sql

SOURCE schema.sql;
SOURCE seeds/initial_setup.sql;

SELECT 'All migrations and seeds complete!' AS Status;
SELECT '================================================' AS '';
SELECT 'Login Credentials:' AS '';
SELECT 'Email: admin@mbadifa.co.ug' AS '';
SELECT 'Password: admin123 (CHANGE THIS IN PRODUCTION!)' AS '';
SELECT '================================================' AS '';
