import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/modern_theme.dart';
import '../../services/member_activation_service.dart';

/// Admin screen to activate member accounts with temporary passwords
class MemberActivationScreen extends StatefulWidget {
  const MemberActivationScreen({super.key});

  @override
  State<MemberActivationScreen> createState() => _MemberActivationScreenState();
}

class _MemberActivationScreenState extends State<MemberActivationScreen> {
  bool _loading = false;
  bool _sendSMS = true;
  List<Map<String, dynamic>> _membersNeedingActivation = [];
  Map<String, dynamic>? _lastResult;

  /// Keeps the content readable on tablets / web / desktop
  static const double _maxContentWidth = 700;

  @override
  void initState() {
    super.initState();
    _loadMembersNeedingActivation();
  }

  Future<void> _loadMembersNeedingActivation() async {
    setState(() => _loading = true);
    try {
      final members = await MemberActivationService.getMembersNeedingActivation();
      if (!mounted) return;
      setState(() {
        _membersNeedingActivation = members;
      });
    } catch (e) {
      _showSnack('Failed to load members: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activateAllMembers() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Confirm Bulk Activation',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to activate ${_membersNeedingActivation.length} member accounts.',
                style: GoogleFonts.inter(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will:',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletPoint('Set temporary passwords for all members'),
                    _buildBulletPoint('Use last 4 digits of account number as password'),
                    if (_sendSMS) _buildBulletPoint('Send SMS with login credentials'),
                    _buildBulletPoint('Members must change password on first login'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_sendSMS)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sms, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SMS will be sent to ${_membersNeedingActivation.length} members',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.success,
              foregroundColor: Colors.white,
            ),
            child: Text('Activate All', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final result = await MemberActivationService.activateAllMembers(
        sendSMS: _sendSMS,
      );

      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });

      if (result['success'] == true) {
        _showSnack(
          'Successfully activated ${result['activated']} members!',
          ModernTheme.success,
        );

        // Show detailed result dialog
        await _showResultDialog(result);

        // Reload members list
        await _loadMembersNeedingActivation();
      } else {
        _showSnack(result['message'] ?? 'Activation failed', Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResultDialog(Map<String, dynamic> result) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Activation Complete',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('Total Members', result['total']?.toString() ?? '0', Icons.people),
              _buildResultRow('Activated', result['activated']?.toString() ?? '0', Icons.check_circle, Colors.green),
              _buildResultRow('Failed', result['failed']?.toString() ?? '0', Icons.error, Colors.red),

              if (result['errors'] != null && (result['errors'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Errors:',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...(result['errors'] as List).take(5).map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $error',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade600),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? ModernTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 14, color: ModernTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.inter(fontSize: 13)),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final pad = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: (canPop || !isMobile)
          ? AppBar(
              backgroundColor: ModernTheme.primaryBlue,
              elevation: 0,
              title: Text(
                'Member Activation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              leading: canPop
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              automaticallyImplyLeading: canPop,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCountCard(isMobile),
                        SizedBox(height: pad),
                        _buildInfoCard(),
                        SizedBox(height: pad),
                        _buildSmsCard(),
                        SizedBox(height: pad + 8),
                        _buildActivateButton(),
                        SizedBox(height: pad),
                        _buildMembersList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ───────────────────────── Sections ─────────────────────────

  Widget _buildCountCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.primaryBlue, ModernTheme.primaryBlue.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people_outline,
              color: Colors.white,
              size: isMobile ? 28 : 32,
            ),
          ),
          SizedBox(width: isMobile ? 14 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_membersNeedingActivation.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'Members Need Activation',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: ModernTheme.primaryBlue),
                const SizedBox(width: 12),
                // Expanded -> title wraps instead of overflowing (was 16px overflow)
                Expanded(
                  child: Text(
                    'What is Member Activation?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Member activation creates login credentials for migrated members who don\'t have accounts yet. '
              'Each member will receive a temporary password (last 4 digits of their account number) and must change it on first login.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: ModernTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        value: _sendSMS,
        onChanged: (value) => setState(() => _sendSMS = value),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        // Icon goes in `secondary` and the title is plain Text,
        // so SwitchListTile handles the wrapping itself (was 45px overflow)
        secondary: Icon(Icons.sms, color: ModernTheme.primaryBlue, size: 22),
        title: Text(
          'Send SMS Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: ModernTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Send login credentials via SMS to all members',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ModernTheme.textSecondary,
            ),
          ),
        ),
        activeColor: ModernTheme.success,
      ),
    );
  }

  Widget _buildActivateButton() {
    final hasMembers = _membersNeedingActivation.isNotEmpty;
    final isDisabled = !hasMembers || _loading;
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isDisabled ? null : _activateAllMembers,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasMembers ? ModernTheme.success : Colors.grey.shade400,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: hasMembers ? 4 : 0,
          shadowColor: hasMembers ? ModernTheme.success.withOpacity(0.4) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasMembers ? Icons.check_circle : Icons.block,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                hasMembers 
                    ? 'ACTIVATE ALL MEMBERS' 
                    : 'NO MEMBERS TO ACTIVATE',
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    if (_membersNeedingActivation.isEmpty) return const SizedBox.shrink();

    final shown = _membersNeedingActivation.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Members Pending Activation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = shown[index];
              final accountNumber = (member['accountNumber'] ?? 'N/A').toString();
              final tempPassword = accountNumber.length >= 4
                  ? accountNumber.substring(accountNumber.length - 4)
                  : 'Auto';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ModernTheme.primaryBlue.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: ModernTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                title: Text(
                  (member['name'] ?? 'Unknown').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account: $accountNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    Text(
                      'Phone: ${member['phone'] ?? 'N/A'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Temp: $tempPassword',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_membersNeedingActivation.length > 10) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '+ ${_membersNeedingActivation.length - 10} more members',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: ModernTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}