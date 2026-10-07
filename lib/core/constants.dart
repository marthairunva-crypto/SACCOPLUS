class AppConstants {
  // ── Branding ──────────────────────────────────────────────────────────────
  static const String appName     = 'MBADIFA SACCO';
  static const String appSubtitle = 'Poverty Must Go';
  static const String appTagline  = 'Empowering Communities • Building Futures';
  static const String appVersion  = '2.0.0';
  static const String logoPath    = 'assets/images/mbadifa-logo.png';

  // ── Image Upload (ImgBB) ──────────────────────────────────────────────────
  static const String imgbbApiKey    = '3f4e8e2c4b5c204728716579fe9355bf';
  static const String imgbbUploadUrl = 'https://api.imgbb.com/1/upload';

  // ── Firestore Collections ─────────────────────────────────────────────────
  // All collections use the saccoplus-* namespace.
  // Core
  static const String usersCol         = 'saccoplus-members';
  static const String saccoCol         = 'saccos';
  static const String branchCol        = 'saccoplus-branches';
  // Loans
  static const String loansCol         = 'saccoplus-loans';
  static const String repaymentsCol    = 'saccoplus-repayments';
  static const String guarantorsCol    = 'saccoplus-guarantors';
  // Savings
  static const String savingsCol       = 'saccoplus-savings';
  static const String savingsTxnCol    = 'saccoplus-savings-transactions';
  static const String fixedDepositCol  = 'saccoplus-fixed-deposits';
  // Shares
  static const String sharesCol        = 'saccoplus-shares';
  static const String dividendsCol     = 'saccoplus-dividends';
  // Wallet & Payments
  static const String walletCol        = 'saccoplus-wallets';
  static const String walletTxnCol     = 'saccoplus-wallet-transactions';
  static const String airtimeTxnCol    = 'saccoplus-airtime-transactions';
  static const String tellerTxnCol     = 'saccoplus-teller-transactions';
  // Notifications & Audit
  static const String notificationsCol = 'saccoplus-notifications';
  static const String auditLogCol      = 'saccoplus-audit-logs';
  // Accounting
  static const String ledgerCol        = 'saccoplus-ledger';
  static const String accountsCol      = 'saccoplus-accounts';
  // Staff & RBAC
  static const String staffCol         = 'saccoplus-staff';
  static const String rolesCol         = 'saccoplus-roles';
  // Till Management
  static const String tillSessionsCol  = 'saccoplus-till-sessions';
  static const String tillEntriesCol   = 'saccoplus-till-entries';

  // ── Loan Statuses ─────────────────────────────────────────────────────────
  static const String statusPending   = 'Pending';
  static const String statusApproved  = 'Approved';
  static const String statusRejected  = 'Rejected';
  static const String statusPaid      = 'Paid';
  static const String statusActive    = 'Active';
  static const String statusDisbursed = 'Disbursed';
  static const String statusOverdue   = 'Overdue';
  static const String statusWrittenOff = 'Written Off';

  // ── User Roles ────────────────────────────────────────────────────────────
  static const String roleMember      = 'Member';  // Capital M to match Firebase data
  static const String roleAdmin       = 'admin';
  static const String roleTeller      = 'teller';
  static const String roleLoanOfficer = 'loan_officer';
  static const String roleManager     = 'manager';
  static const String roleSuperAdmin  = 'super_admin';

  // ── Savings Types ─────────────────────────────────────────────────────────
  static const String savingsVoluntary   = 'Voluntary';
  static const String savingsCompulsory  = 'Compulsory';
  static const String savingsFixedDeposit = 'Fixed Deposit';
  static const String savingsShareCapital = 'Share Capital';

  // ── Wallet Limits (UGX) ───────────────────────────────────────────────────
  static const int walletDailyLimit  = 5000000;  // UGX 5M
  static const int walletMinWithdraw = 1000;      // UGX 1K
  // Charges — MarzPay API fees + platform margin (updated Sept 2026)
  static const double walletDepositChargePercent  = 0.03; // 3.2% collection
  static const double walletWithdrawChargePercent = 0.035; // 3.5% disbursement
  static const int    walletMinCharge             = 200;  // UGX 200 minimum

  // ── MarzPay (Mobile Money) ────────────────────────────────────────────────
  static const String marzPayBaseUrl    = 'https://wallet.wearemarz.com/api/v1';
  static const String marzPayBase64Auth = 'bWFyel9TTmdZMHRwb1FVcFk1WmNoOndIRWdTT0lhUjhCUjNMMDV2NlZFUHFzMTBOZFdNZzU4';
  static const String marzPayCountry    = 'UG';

  // ── Proxy Config ──────────────────────────────────────────────────────────
  static const String marzPayProxyUrl = 'https://proxy.godsfavouroutreachmission.org/marzpay_proxy.php';
  static const String marzPayProxyKey = 'saccoplus_pro_2025_proxy_key';
  static const bool   useRenderProxy  = true;
  static const String renderProxyUrl  = 'https://marzpay-proxy.onrender.com';
  
  // Local development proxy (when running proxy server locally)
  static const bool   useLocalProxy   = false;  // Set to false for web testing
  static const String localProxyUrl   = 'http://localhost:10000';
  
  // Get active proxy URL based on configuration and platform
  static String get activeProxyUrl {
    // On web, always use remote proxy (CORS issue with localhost)
    if (identical(0, 0.0)) { // This is always true, placeholder for kIsWeb check
      return renderProxyUrl;
    }
    return useLocalProxy ? localProxyUrl : renderProxyUrl;
  }

  // ── Bank Transfer ─────────────────────────────────────────────────────────
  static const int bankTransferMinAmount = 2500; // UGX

  // ── Marz Pay (Airtime & Data) ─────────────────────────────────────────────
  // Marz Pay Airtime & Data API - MTN Uganda only
  // Market: Uganda (UGX) • 0% platform charges
  // Synchronous processing (no callbacks)

  // ── SaaS / Subscription Tiers ─────────────────────────────────────────────
  static const Map<String, int> subscriptionPrices = {
    'Starter':      150000,  // UGX/month — up to 100 members
    'Growth':       350000,  // UGX/month — up to 500 members
    'Professional': 700000,  // UGX/month — up to 2000 members
    'Enterprise':   0,       // Custom pricing
  };

  // ── Company ───────────────────────────────────────────────────────────────
  static const String companyName    = 'Infinitech Innovations Ltd';
  static const String companyCity    = 'Mbarara, Uganda';
  static const String companyWebsite = 'www.infinitech.co.ug';
  static const String companyContact = '+256778474686';
  static const String companyEmail   = 'info@infinitech.co.ug';
  static String get companyCopyright =>
      '© ${DateTime.now().year} Infinitech Innovations Ltd. All rights reserved.';
}
