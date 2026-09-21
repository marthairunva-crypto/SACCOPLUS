import 'package:flutter/material.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../core/account_number_service.dart';
import '../farmer/farmer_scaffold.dart';
import '../admin/admin_home.dart';

/// Modern, clean login screen inspired by professional web designs
class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _useAccountNumber = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    
    if (identifier.isEmpty || pin.length != 4) {
      _showSnack(
        _useAccountNumber
            ? 'Enter your account number and 4-digit PIN'
            : 'Enter your phone number and 4-digit PIN',
        ModernTheme.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      Map<String, dynamic>? profile;
      String uid;

      if (_useAccountNumber) {
        profile = await AccountNumberService.getMemberByAccountNumber(identifier);
        if (profile == null) {
          _showSnack('Account number not found', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? profile['phone'] as String? ?? '';
      } else {
        final phone = FirebaseService.formatPhone(identifier);
        profile = await FirebaseService.getProfileByPhone(phone);
        if (profile == null) {
          _showSnack('No account found. Please register.', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? 'phone_$phone';
      }

      final pinOk = await FirebaseService.verifyPin(uid, pin);
      if (!pinOk) {
        _showSnack('Incorrect PIN', ModernTheme.error);
        return;
      }

      await FirebaseService.saveSession(uid, profile);
      
      if (!mounted) return;
      
      final role = profile['role'] as String? ?? '';
      if (role == 'admin' || role == 'super_admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHome()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FarmerScaffold()),
        );
      }
    } catch (e) {
      _showSnack('Login failed: ${e.toString()}', ModernTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  _buildHeader(),
                  
                  const SizedBox(height: 48),
                  
                  // Login Card
                  _buildLoginCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Register Link
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: ModernTheme.headerGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: ModernTheme.cardShadow,
          ),
          child: const Icon(
            Icons.account_balance,
            size: 40,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Title
        Text(
          'SACCOPLUS',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ModernTheme.primaryBlue,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Your trusted SACCO management system',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: ModernTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ModernTheme.borderLight),
        boxShadow: ModernTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Text
          Text(
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Login to access your account',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Login Method Toggle
          _buildLoginMethodToggle(),
          
          const SizedBox(height: 24),
          
          // Identifier Field
          TextFormField(
            controller: _identifierCtrl,
            decoration: InputDecoration(
              labelText: _useAccountNumber ? 'Account Number' : 'Phone Number',
              prefixIcon: Icon(
                _useAccountNumber ? Icons.badge : Icons.phone,
                color: ModernTheme.primaryBlue,
              ),
              hintText: _useAccountNumber ? '60000001' : '0700000000',
            ),
            keyboardType: _useAccountNumber
                ? TextInputType.number
                : TextInputType.phone,
          ),
          
          const SizedBox(height: 16),
          
          // PIN Field
          TextFormField(
            controller: _pinCtrl,
            decoration: const InputDecoration(
              labelText: '4-Digit PIN',
              prefixIcon: Icon(
                Icons.lock,
                color: ModernTheme.primaryBlue,
              ),
              hintText: '••••',
            ),
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
          ),
          
          const SizedBox(height: 24),
          
          // Login Button
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildLoginMethodToggle() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _useAccountNumber = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_useAccountNumber
                    ? ModernTheme.primaryBlue
                    : Colors.transparent,
                border: Border.all(
                  color: ModernTheme.primaryBlue,
                  width: 1.5,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Text(
                'Phone Number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: !_useAccountNumber
                      ? Colors.white
                      : ModernTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _useAccountNumber = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _useAccountNumber
                    ? ModernTheme.primaryBlue
                    : Colors.transparent,
                border: Border.all(
                  color: ModernTheme.primaryBlue,
                  width: 1.5,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                'Account Number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _useAccountNumber
                      ? Colors.white
                      : ModernTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _loading ? null : _login,
      style: ModernTheme.successButton,
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text('LOG IN'),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: () {
            // Navigate to register screen
          },
          child: const Text('SIGN UP'),
        ),
      ],
    );
  }
}
