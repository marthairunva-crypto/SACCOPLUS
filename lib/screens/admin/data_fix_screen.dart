import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../scripts/fix_loan_outstanding_fields.dart';
import '../../scripts/fix_member_role_field.dart';

/// Admin screen for running data fixes and migrations
class DataFixScreen extends StatefulWidget {
  const DataFixScreen({Key? key}) : super(key: key);

  @override
  State<DataFixScreen> createState() => _DataFixScreenState();
}

class _DataFixScreenState extends State<DataFixScreen> {
  bool _isRunningLoans = false;
  bool _isRunningMembers = false;
  String _loanStatus = 'Ready to fix loan outstanding fields';
  String _memberStatus = 'Ready to add missing role fields to members';
  Map<String, int>? _loanResults;
  Map<String, int>? _memberResults;

  Future<void> _runLoanFix() async {
    setState(() {
      _isRunningLoans = true;
      _loanStatus = 'Running fix... Please wait...';
      _loanResults = null;
    });

    try {
      final results = await FixLoanOutstandingFields.fixAllLoans();
      
      setState(() {
        _isRunningLoans = false;
        _loanStatus = 'Fix completed successfully!';
        _loanResults = results;
      });
    } catch (e) {
      setState(() {
        _isRunningLoans = false;
        _loanStatus = 'Error: $e';
        _loanResults = null;
      });
    }
  }

  Future<void> _runMemberFix() async {
    setState(() {
      _isRunningMembers = true;
      _memberStatus = 'Running fix... Please wait...';
      _memberResults = null;
    });

    try {
      final results = await FixMemberRoleField.fixAllMembers();
      
      setState(() {
        _isRunningMembers = false;
        _memberStatus = 'Fix completed successfully!';
        _memberResults = results;
      });
    } catch (e) {
      setState(() {
        _isRunningMembers = false;
        _memberStatus = 'Error: $e';
        _memberResults = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Fixes', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF059669),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MEMBER ROLE FIX
            Text(
              'Member Role Field Fix',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Members without a "role" field won\'t appear in loan creation. This adds the missing role.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'What it does:',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _bulletPoint('Finds all members without a role field'),
            _bulletPoint('Adds role: "Member" to each one'),
            _bulletPoint('Safe to run multiple times'),
            const SizedBox(height: 24),
            _buildFixCard(
              isRunning: _isRunningMembers,
              status: _memberStatus,
              results: _memberResults,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRunningMembers ? null : _runMemberFix,
              icon: const Icon(Icons.person_add),
              label: Text(
                'Fix Member Roles',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 48),
            const Divider(thickness: 2),
            const SizedBox(height: 48),
            
            // LOAN OUTSTANDING FIX
            Text(
              'Loan Outstanding Fields Fix',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This tool fixes inconsistent outstanding balance calculations across all loans.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'What it does:',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _bulletPoint('Recalculates principalOutstanding, interestOutstanding, chargesOutstanding'),
            _bulletPoint('Sets remainingBalance, totalOutstanding, outstanding'),
            _bulletPoint('Ensures all payment fields are consistent'),
            _bulletPoint('Safe to run multiple times'),
            const SizedBox(height: 24),
            _buildFixCard(
              isRunning: _isRunningLoans,
              status: _loanStatus,
              results: _loanResults,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRunningLoans ? null : _runLoanFix,
              icon: const Icon(Icons.build),
              label: Text(
                'Fix Loan Outstanding',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixCard({
    required bool isRunning,
    required String status,
    required Map<String, int>? results,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRunning 
            ? Colors.blue[50]
            : (results != null 
                ? Colors.green[50] 
                : Colors.grey[100]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRunning 
              ? Colors.blue[200]! 
              : (results != null 
                  ? Colors.green[200]! 
                  : Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isRunning)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  results != null ? Icons.check_circle : Icons.info_outline,
                  color: results != null ? Colors.green : Colors.blue,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (results != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _resultRow('Total', results['total'].toString()),
            _resultRow('Fixed', results['fixed'].toString(), Colors.green),
            _resultRow('Skipped', results['skipped'].toString(), Colors.blue),
            if (results['errors']! > 0)
              _resultRow('Errors', results['errors'].toString(), Colors.red),
          ],
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
