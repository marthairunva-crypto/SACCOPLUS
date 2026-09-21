import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../auth/professional_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loanAlerts     = true;
  bool _paymentAlerts  = true;
  bool _promoAlerts    = false;
  bool _biometric      = false;
  bool _loading        = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _loanAlerts    = prefs.getBool('notif_loans')    ?? true;
        _paymentAlerts = prefs.getBool('notif_payments') ?? true;
        _promoAlerts   = prefs.getBool('notif_promo')    ?? false;
        _biometric     = prefs.getBool('biometric')      ?? false;
        _loading       = false;
      });
    }
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _changePin() {
    // Show dialog instead since OTP screens were removed
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_reset, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Change PIN'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To change your PIN, please contact our support team:',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              '+256 778474686',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Our team will verify your identity and help you change your PIN securely.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(AppConstants.logoPath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Text(AppConstants.appName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Version ${AppConstants.appVersion}',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(AppConstants.appTagline,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(AppConstants.companyCopyright,
                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSupport() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help & Support',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 16),
            _supportRow(Icons.phone_rounded, 'Call Us', AppConstants.companyContact),
            _supportRow(Icons.email_rounded, 'Email Us', AppConstants.companyEmail),
            _supportRow(Icons.language_rounded, 'Website', AppConstants.companyWebsite),
            _supportRow(Icons.location_on_rounded, 'Location', AppConstants.companyCity),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _supportRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 18),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final profile = FirebaseService.sessionProfile;
    final name  = profile?['name']  as String? ?? 'Member';
    final phone = profile?['phone'] as String? ?? '';
    final role  = profile?['role']  as String? ?? AppConstants.roleMember;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Profile card ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(phone, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(role.toUpperCase(),
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ])),
                  ]),
                ),

                // ── Notifications ────────────────────────────────────────
                _sectionHeader('Notifications'),
                _switchTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Loan Alerts',
                  subtitle: 'Loan approvals, rejections and reminders',
                  value: _loanAlerts,
                  onChanged: (v) { setState(() => _loanAlerts = v); _save('notif_loans', v); },
                ),
                _switchTile(
                  icon: Icons.payments_rounded,
                  title: 'Payment Alerts',
                  subtitle: 'Deposits, withdrawals and repayments',
                  value: _paymentAlerts,
                  onChanged: (v) { setState(() => _paymentAlerts = v); _save('notif_payments', v); },
                ),
                _switchTile(
                  icon: Icons.campaign_rounded,
                  title: 'Promotions & Updates',
                  subtitle: 'SACCO news and product updates',
                  value: _promoAlerts,
                  onChanged: (v) { setState(() => _promoAlerts = v); _save('notif_promo', v); },
                ),

                const SizedBox(height: 8),

                // ── Security ─────────────────────────────────────────────
                _sectionHeader('Security'),
                _actionTile(
                  icon: Icons.dialpad_rounded,
                  title: 'Change PIN',
                  subtitle: 'Update your 4-digit login PIN',
                  onTap: _changePin,
                ),
                _switchTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Login',
                  subtitle: 'Use fingerprint or Face ID to sign in',
                  value: _biometric,
                  onChanged: (v) { setState(() => _biometric = v); _save('biometric', v); },
                ),

                const SizedBox(height: 8),

                // ── App ───────────────────────────────────────────────────
                _sectionHeader('App'),
                _actionTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Contact us, FAQs',
                  onTap: _showSupport,
                ),
                _actionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About SACCOPLUS Pro',
                  subtitle: 'Version ${AppConstants.appVersion}',
                  onTap: _showAbout,
                ),
                _actionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () => _showSimpleDialog('Privacy Policy',
                      'SACCOPLUS Pro collects and processes your personal data '
                      'in accordance with the Uganda Data Protection and Privacy Act 2019. '
                      'Your data is stored securely and never shared with third parties '
                      'without your consent. Contact ${AppConstants.companyEmail} for data requests.'),
                ),
                _actionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Usage terms and conditions',
                  onTap: () => _showSimpleDialog('Terms of Service',
                      'By using SACCOPLUS Pro, you agree to use the platform '
                      'only for lawful SACCO-related activities. '
                      'Infinitech Innovations Ltd reserves the right to suspend accounts '
                      'that violate these terms. For full terms, visit ${AppConstants.companyWebsite}.'),
                ),

                const SizedBox(height: 8),

                // ── Danger zone ───────────────────────────────────────────
                _sectionHeader('Account'),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
                      title: Text('Sign Out',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.error)),
                      subtitle: Text('Sign out of your account',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                      onTap: () => _confirmSignOut(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: Text(AppConstants.companyCopyright,
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(title,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: AppTheme.primary, letterSpacing: 0.5)),
  );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: SwitchListTile(
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          title: Text(title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          title: Text(title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(content,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
