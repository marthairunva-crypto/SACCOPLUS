/// One-time migration screen for converting to multi-tenant architecture.
/// Only accessible to super_admin or admin users.
/// Run once, then this screen can be removed from the app.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/migration_to_multitenant.dart';
import '../../core/theme.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _migrating = false;
  bool _complete = false;
  bool _generatingAccounts = false;
  bool _accountsComplete = false;
  final List<Map<String, dynamic>> _logs = [];
  final List<Map<String, dynamic>> _accountLogs = [];
  int _totalUpdated = 0;
  int _totalSkipped = 0;
  int _totalAccountsGenerated = 0;
  int _totalAccountsSkipped = 0;

  Future<void> _generateAccountNumbers() async {
    if (_generatingAccounts) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Generate Account Numbers',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will create account numbers for all existing members.\n\n'
          'Format: {SACCO}-0001, {SACCO}-0002, etc.\n\n'
          'Safe to run multiple times.\n\n'
          'Continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Generate',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _generatingAccounts = true;
      _accountLogs.clear();
      _totalAccountsGenerated = 0;
      _totalAccountsSkipped = 0;
    });

    await for (final event in MultiTenantMigration.generateAccountNumbers()) {
      if (mounted) {
        setState(() {
          _accountLogs.add(event);
          if (event['totalGenerated'] != null) {
            _totalAccountsGenerated = event['totalGenerated'] as int;
          }
          if (event['totalSkipped'] != null) {
            _totalAccountsSkipped = event['totalSkipped'] as int;
          }
          if (event['status'] == 'complete') _accountsComplete = true;
        });
      }
    }

    if (mounted) {
      setState(() => _generatingAccounts = false);
    }
  }

  Future<void> _runMigration() async {
    if (_migrating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️ Confirm Migration',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will add tenantId to all existing records.\n\n'
          'It is SAFE to run multiple times.\n\n'
          'Existing data will NOT be deleted.\n\n'
          'Continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Migrate',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _migrating = true;
      _logs.clear();
      _totalUpdated = 0;
      _totalSkipped = 0;
    });

    await for (final event in MultiTenantMigration.migrate()) {
      if (mounted) {
        setState(() {
          _logs.add(event);
          if (event['updated'] != null) _totalUpdated += event['updated'] as int;
          if (event['skipped'] != null) _totalSkipped += event['skipped'] as int;
          if (event['status'] == 'done') _complete = true;
        });
      }
    }

    if (mounted) {
      setState(() => _migrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Multi-Tenant Migration',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.info),
                      const SizedBox(width: 8),
                      Text('What This Does',
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.info)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Step 1: Adds tenantId = "sacco_001" to all existing records\n'
                    '• Step 2: Generates account numbers for all members\n'
                    '• Safe to run multiple times\n'
                    '• Does NOT delete any data',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Start tenantId migration button
            if (!_migrating && !_complete)
              ElevatedButton.icon(
                onPressed: _runMigration,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text('1. Migrate to Multi-Tenant',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

            // Account number generation button (only show after tenantId migration)
            if (_complete && !_generatingAccounts && !_accountsComplete)
              Column(
                children: [
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _generateAccountNumbers,
                    icon: const Icon(Icons.badge_rounded),
                    label: Text('2. Generate Account Numbers',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

            // Summary card for tenantId migration
            if (_migrating || _complete)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _complete
                      ? AppTheme.success.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _complete
                          ? AppTheme.success
                          : const Color(0xFFE4E8F0)),
                ),
                child: Column(
                  children: [
                    if (_migrating && !_complete)
                      const CircularProgressIndicator(
                          color: AppTheme.primary),
                    if (_complete)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _complete
                          ? '✅ TenantId Migration Complete!'
                          : 'Migrating to multi-tenant...',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated: $_totalUpdated documents\n'
                      'Skipped: $_totalSkipped (already had tenantId)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

            // Summary card for account number generation
            if (_generatingAccounts || _accountsComplete)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accountsComplete
                          ? AppTheme.success.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _accountsComplete
                              ? AppTheme.success
                              : const Color(0xFFE4E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (_generatingAccounts && !_accountsComplete)
                          const CircularProgressIndicator(
                              color: AppTheme.accent),
                        if (_accountsComplete)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _accountsComplete
                              ? '✅ Account Numbers Generated!'
                              : 'Generating account numbers...',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generated: $_totalAccountsGenerated account numbers\n'
                          'Skipped: $_totalAccountsSkipped (already had one)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Logs
            if (_logs.isNotEmpty || _accountLogs.isNotEmpty) ...[
              Text('Migration Log',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E8F0)),
                  ),
                  child: ListView(
                    children: [
                      ..._logs.map((log) => _buildLogEntry(log)),
                      if (_accountLogs.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        ..._accountLogs.map((log) => _buildLogEntry(log)),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            if (_complete && _accountsComplete) ...[
              const SizedBox(height: 16),
              Text(
                '🎉 ALL MIGRATIONS COMPLETE!\n\n'
                '✅ Multi-tenant: $_totalUpdated records\n'
                '✅ Account numbers: $_totalAccountsGenerated generated\n\n'
                'Next: Create super_admin & test!',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ] else if (_complete) ...[
              const SizedBox(height: 16),
              Text(
                '✅ Step 1 Complete!\n\n'
                '👉 Now tap "2. Generate Account Numbers"',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.info,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final collection = log['collection'] as String? ?? '';
    final status = log['status'] as String? ?? '';

    IconData icon;
    Color color;

    switch (status) {
      case 'complete':
        icon = Icons.check_circle_rounded;
        color = AppTheme.success;
        break;
      case 'error':
        icon = Icons.error_rounded;
        color = AppTheme.error;
        break;
      case 'progress':
        icon = Icons.sync_rounded;
        color = AppTheme.info;
        break;
      default:
        icon = Icons.hourglass_empty_rounded;
        color = Colors.grey;
    }

    String message = collection;
    if (log['updated'] != null) {
      message += ' → ${log['updated']} updated, ${log['skipped']} skipped';
    }
    if (log['message'] != null) {
      message = log['message'];
    }
    if (log['error'] != null) {
      message += ' → ERROR: ${log['error']}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.robotoMono(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
