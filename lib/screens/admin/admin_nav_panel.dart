import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';

// ─── Navigation model ─────────────────────────────────────────────────────────

class NavItem {
  final String label;
  final String route;
  const NavItem(this.label, this.route);
}

class NavGroup {
  final String title;
  final IconData icon;
  final List<NavItem> items;
  const NavGroup(this.title, this.icon, this.items);
}

/// Single source of truth for the admin menu. Edit here and both the desktop
/// sidebar and the mobile drawer update together.
const kAdminNavGroups = <NavGroup>[
  NavGroup('Members', Icons.people_alt_outlined, [
    NavItem('All Members', 'members'),
    NavItem('Activate Members', 'member_activation'),
    NavItem('Member 360', 'member_360'),
    NavItem('KYC & Verification', 'kyc'),
    NavItem('Dormant Accounts', 'dormant'),
  ]),
  NavGroup('Savings & Shares', Icons.savings_outlined, [
    NavItem('Savings Management', 'savings'),
    NavItem('Savings Summary', 'savings_summary'),
    NavItem('Shares Management', 'shares'),
    NavItem('Fixed Deposits', 'fixed_deposits'),
    NavItem('Dividends', 'dividends'),
  ]),
  NavGroup('Loans', Icons.request_quote_outlined, [
    NavItem('Create & Disburse Loan', 'create_loan'),
    NavItem('Loan Applications', 'loans'),
    NavItem('Correct Loan Data', 'loan_correction'),
    NavItem('Loan Products', 'loan_products'),
    NavItem('Loan Calculator', 'loan_calc'),
    NavItem('Arrears Management', 'arrears'),
    NavItem('Risk & Provisioning', 'risk_provision'),
  ]),
  NavGroup('Teller Center', Icons.point_of_sale_outlined, [
    NavItem('Teller Operations', 'teller'),
    NavItem('Till Management', 'till_management'),
    NavItem('Till Reports', 'till_reports'),
    NavItem('Income', 'income'),
    NavItem('Expenses', 'expenses'),
    NavItem('Payment Hub', 'payment_hub'),
    NavItem('Mobile Money', 'mobile_money'),
    NavItem('Bank Transfers', 'bank_transfers'),
    NavItem('Reconciliation', 'reconciliation'),
  ]),
  NavGroup('Finance', Icons.account_balance_outlined, [
    NavItem('Cash & Bank', 'cash_bank'),
    NavItem('General Ledger', 'ledger'),
    NavItem('Financial Reports', 'financial_reports'),
  ]),
  NavGroup('Intelligence', Icons.insights_outlined, [
    NavItem('Loan Risk Center', 'risk_center'),
    NavItem('Liquidity Monitor', 'liquidity'),
  ]),
  NavGroup('Operations', Icons.work_outline_rounded, [
    NavItem('Staff Management', 'staff'),
    NavItem('Notifications', 'notifications'),
  ]),
  NavGroup('System', Icons.settings_outlined, [
    NavItem('SACCO Settings', 'settings'),
    NavItem('Audit Trail', 'audit'),
  ]),
];

/// Screens that are reached from a menu item but are not in the menu
/// themselves. They highlight their parent item.
const _routeAliases = <String, String>{
  'loan_details': 'loans',
};

// ─── Palette ──────────────────────────────────────────────────────────────────

class _Nav {
  static const bg = Color(0xFF0F1B2D);
  static const popup = Color(0xFF16253B);
  static const text = Color(0xFFE8EDF4);
  static const muted = Color(0xFF9AA8BC);
  static const accent = Color(0xFF4C9AFF);
  static const line = Color(0x1AFFFFFF); // white @ 10%
  static const selected = Color(0x1FFFFFFF); // white @ 12%
  static const hover = Color(0x0FFFFFFF); // white @ 6%
  static const danger = Color(0xFFF2877E);
}

/// Size tokens. Instead of a few fixed tiers, every value is derived from a
/// single [row] height, and the panel picks the biggest row that still fits
/// the height it is given. When even the biggest row leaves free space, that
/// space is spread evenly between the items ([extraGap]). Result: the menu
/// fills the sidebar from top to bottom at any window height.
class _M {
  static const double minRow = 38;
  static const double span = 22; // row range: 38 .. 60

  final double row, child, font, childFont, icon, gap, sectionGap;
  final double logo, rail, headerTop, headerBottom, brandFont, accountPad;
  final double extraGap;

  const _M._({
    required this.row,
    required this.child,
    required this.font,
    required this.childFont,
    required this.icon,
    required this.gap,
    required this.sectionGap,
    required this.logo,
    required this.rail,
    required this.headerTop,
    required this.headerBottom,
    required this.brandFont,
    required this.accountPad,
    required this.extraGap,
  });

  factory _M.fromRow(double row, [double extraGap = 0]) {
    final t = math.min(1.0, math.max(0.0, (row - minRow) / span));
    double l(double a, double b) => a + (b - a) * t;
    return _M._(
      row: row,
      child: row * 0.84,
      font: l(14, 15.5),
      childFont: l(13, 14.5),
      icon: l(20, 23),
      gap: l(1, 3) + extraGap,
      sectionGap: l(8, 20),
      logo: l(36, 48),
      rail: row + 2,
      headerTop: l(12, 28),
      headerBottom: l(12, 24),
      brandFont: l(14, 16.5),
      accountPad: l(2, 8),
      extraGap: extraGap,
    );
  }

  /// Largest row (up to [maxRow]) whose content fits in [available]; any
  /// leftover space becomes extra gap between top-level items.
  static _M fit({
    required double available,
    required double Function(_M m) content,
    required int tiles,
    double maxRow = minRow + span,
    double maxExtra = 12,
  }) {
    if (!available.isFinite) return _M.fromRow(46);

    var best = _M.fromRow(minRow);
    for (var r = maxRow; r >= minRow; r -= 0.5) {
      final cand = _M.fromRow(r);
      if (content(cand) <= available - 1) {
        best = cand;
        break;
      }
    }

    if (best.row >= maxRow) {
      final left = available - 1 - content(best);
      if (left > 0) {
        best = _M.fromRow(maxRow, math.min(maxExtra, left / (tiles * 2)));
      }
    }
    return best;
  }
}

/// Below this width the panel draws itself as a slim icon rail. The decision
/// is made from the width the panel is actually given, so it also behaves
/// correctly while the parent animates its width.
const double _railBelow = 180;

// ─── Panel ────────────────────────────────────────────────────────────────────

/// Navigation panel shared by the desktop sidebar and the mobile drawer.
///
/// It adapts to whatever size it is given: a full menu when wide, an icon rail
/// (with pop-up submenus) when narrow, and rows that grow or shrink so the
/// menu always fills the available height.
class AdminNavPanel extends StatefulWidget {
  final String currentScreen;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  /// Desktop only. When set, a collapse / expand control is shown.
  final VoidCallback? onToggleCollapse;

  const AdminNavPanel({
    super.key,
    required this.currentScreen,
    required this.onNavigate,
    required this.onLogout,
    this.onToggleCollapse,
  });

  static const Color background = _Nav.bg;

  @override
  State<AdminNavPanel> createState() => _AdminNavPanelState();
}

class _AdminNavPanelState extends State<AdminNavPanel> {
  String? _openGroup;

  static String _resolve(String route) => _routeAliases[route] ?? route;

  static NavGroup? _groupOf(String route) {
    final r = _resolve(route);
    for (final g in kAdminNavGroups) {
      if (g.items.any((i) => i.route == r)) return g;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _openGroup = _groupOf(widget.currentScreen)?.title;
  }

  @override
  void didUpdateWidget(covariant AdminNavPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentScreen != widget.currentScreen) {
      final g = _groupOf(widget.currentScreen);
      if (g != null) _openGroup = g.title;
    }
  }

  int get _openItems {
    for (final g in kAdminNavGroups) {
      if (g.title == _openGroup) return g.items.length;
    }
    return 0;
  }

  /// Total pixel height of the full menu for a given size set.
  double _fullHeight(_M m) {
    final pinBottom = widget.onToggleCollapse != null;
    final header = m.headerTop + math.max(m.logo, 48.0) + m.headerBottom + 1;
    final account = 2 * m.accountPad + 48 + 1;
    final listPad = 12.0 + (pinBottom ? 12 : 28);
    final tiles = (1 + kAdminNavGroups.length) * (m.row + 2 * m.gap);
    final open = _openItems > 0 ? _openItems * (m.child + 2) + 8 : 0;
    return header + account + listPad + tiles + m.sectionGap + open;
  }

  /// Total pixel height of the icon rail for a given size set.
  double _railHeight(_M m) {
    final head = 18 + m.logo + 16 + 1;
    const sign = 56.0 + 1;
    const listPad = 24.0;
    final tiles = (1 + kAdminNavGroups.length) * (m.rail + 2 * m.gap) + 8;
    final expand = widget.onToggleCollapse != null ? 6.0 + 48 : 0.0;
    return head + sign + listPad + tiles + expand;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _resolve(widget.currentScreen);
    final tileCount = 1 + kAdminNavGroups.length;

    return Material(
      color: _Nav.bg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rail = constraints.maxWidth < _railBelow;
            final target = rail
                ? _M.fit(
                    available: constraints.maxHeight,
                    content: _railHeight,
                    tiles: tileCount,
                    maxRow: 54,
                    maxExtra: 14,
                  )
                : _M.fit(
                    available: constraints.maxHeight,
                    content: _fullHeight,
                    tiles: tileCount,
                  );

            // Animate size changes (window resize, opening / closing a group)
            // so rows glide instead of jumping. dx = row height, dy = gap.
            return TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(end: Offset(target.row, target.extraGap)),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              builder: (context, v, _) {
                final m = _M.fromRow(v.dx, v.dy);
                return rail ? _buildRail(selected, m) : _buildFull(selected, m);
              },
            );
          },
        ),
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────────────

  Widget _logo([double size = 40]) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.asset(
        'assets/images/mbadifa-logo.png',
        fit: BoxFit.contain,
      ),
    );
  }

  static const _divider = Divider(height: 1, thickness: 1, color: _Nav.line);

  // ── Full layout ────────────────────────────────────────────────────────

  Widget _buildFull(String selected, _M m) {
    // Desktop (collapse control present): account pinned to the bottom, the
    // usual sidebar layout. Mobile drawer: account stays at the top so it can
    // never sit under a gesture bar or browser toolbar.
    final pinAccountBottom = widget.onToggleCollapse != null;
    return Column(
      children: [
        _buildHeader(m),
        _divider,
        if (!pinAccountBottom) ...[_buildAccount(m), _divider],
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 12, 12, pinAccountBottom ? 12 : 28),
            children: [
              _NavTile(
                label: 'Dashboard',
                icon: Icons.space_dashboard_outlined,
                m: m,
                selected: selected == 'dashboard',
                onTap: () => widget.onNavigate('dashboard'),
              ),
              SizedBox(height: m.sectionGap),
              for (final g in kAdminNavGroups) _buildGroup(g, selected, m),
            ],
          ),
        ),
        if (pinAccountBottom) ...[_divider, _buildAccount(m)],
      ],
    );
  }

  Widget _buildHeader(_M m) {
    final canCollapse = widget.onToggleCollapse != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, m.headerTop, canCollapse ? 8 : 16, m.headerBottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            _logo(m.logo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MBADIFA SACCO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: m.brandFont,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    AppConstants.appSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _Nav.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (canCollapse)
              IconButton(
                onPressed: widget.onToggleCollapse,
                tooltip: 'Collapse menu',
                icon: const Icon(Icons.keyboard_double_arrow_left_rounded,
                    size: 20),
                color: _Nav.muted,
                hoverColor: _Nav.hover,
              ),
          ],
        ),
      ),
    );
  }

  /// Account + sign-out. On desktop it is pinned to the bottom; in the mobile
  /// drawer it sits at the top so it can never be hidden behind a phone's
  /// gesture bar or a browser toolbar.
  Widget _buildAccount(_M m) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, m.accountPad, 8, m.accountPad),
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined,
              size: 20, color: _Nav.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Administrator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: _Nav.text,
                fontSize: m.childFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onLogout,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, size: 19),
            color: _Nav.danger,
            hoverColor: _Nav.hover,
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(NavGroup group, String selected, _M m) {
    final open = _openGroup == group.title;
    final hasActive = group.items.any((i) => i.route == selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavTile(
          label: group.title,
          icon: group.icon,
          m: m,
          selected: false,
          emphasised: hasActive,
          trailing: AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: _Nav.muted),
          ),
          onTap: () => setState(() => _openGroup = open ? null : group.title),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.only(left: 21, top: 2, bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: _Nav.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in group.items)
                          _NavTile(
                            label: item.label,
                            dense: true,
                            m: m,
                            selected: item.route == selected,
                            onTap: () => widget.onNavigate(item.route),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // ── Icon-rail layout ───────────────────────────────────────────────────

  Widget _buildRail(String selected, _M m) {
    final pinAccountBottom = widget.onToggleCollapse != null;
    final signOut = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: IconButton(
          onPressed: widget.onLogout,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, size: 20),
          color: _Nav.danger,
          hoverColor: _Nav.hover,
        ),
      ),
    );

    return Column(
      children: [
        const SizedBox(height: 18),
        Center(child: _logo(m.logo)),
        const SizedBox(height: 16),
        _divider,
        if (!pinAccountBottom) ...[signOut, _divider],
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: m.gap),
                child: Center(
                  child: _RailTile(
                    icon: Icons.space_dashboard_outlined,
                    size: m.rail,
                    tooltip: 'Dashboard',
                    selected: selected == 'dashboard',
                    onTap: () => widget.onNavigate('dashboard'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final g in kAdminNavGroups) _buildRailGroup(g, selected, m),
            ],
          ),
        ),
        if (pinAccountBottom) ...[_divider, signOut],
        if (widget.onToggleCollapse != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Center(
              child: IconButton(
                onPressed: widget.onToggleCollapse,
                tooltip: 'Expand menu',
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded,
                    size: 20),
                color: _Nav.muted,
                hoverColor: _Nav.hover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRailGroup(NavGroup group, String selected, _M m) {
    final hasActive = group.items.any((i) => i.route == selected);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.gap),
      child: Center(
        child: PopupMenuButton<String>(
          tooltip: group.title,
          color: _Nav.popup,
          elevation: 8,
          offset: const Offset(56, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _Nav.line),
          ),
          onSelected: widget.onNavigate,
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              height: 34,
              child: Text(
                group.title.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: _Nav.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final item in group.items)
              PopupMenuItem<String>(
                value: item.route,
                height: 40,
                child: Text(
                  item.label,
                  style: GoogleFonts.poppins(
                    color: item.route == selected ? Colors.white : _Nav.text,
                    fontSize: 13,
                    fontWeight: item.route == selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: _RailTile(icon: group.icon, selected: hasActive, size: m.rail),
        ),
      ),
    );
  }
}

// ─── Rows ─────────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool emphasised;
  final bool dense;
  final _M m;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavTile({
    required this.label,
    required this.onTap,
    required this.m,
    this.icon,
    this.selected = false,
    this.emphasised = false,
    this.dense = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? Colors.white
        : emphasised
            ? _Nav.text
            : _Nav.muted;
    final FontWeight weight =
        (selected || emphasised) ? FontWeight.w600 : FontWeight.w500;

    return Padding(
      // Sub-items keep a tight 1px gap; top-level items get the spread gap.
      padding: EdgeInsets.symmetric(vertical: dense ? 1.0 : m.gap),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? _Nav.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: _Nav.hover,
            splashColor: _Nav.hover,
            highlightColor: _Nav.hover,
            child: SizedBox(
              height: dense ? m.child : m.row,
              child: Row(
                children: [
                  SizedBox(width: dense ? 12 : 14),
                  if (icon != null) ...[
                    Icon(icon, size: m.icon, color: selected ? _Nav.accent : fg),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: fg,
                        fontSize: dense ? m.childFont : m.font,
                        fontWeight: weight,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon button used in the collapsed rail. When [onTap] is null the tile is
/// purely visual (a PopupMenuButton wraps it and handles the tap).
class _RailTile extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;
  final double size;

  const _RailTile({
    required this.icon,
    this.size = 44,
    this.selected = false,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _Nav.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon,
          size: size * 0.5, color: selected ? _Nav.accent : _Nav.muted),
    );

    if (onTap == null) return tile;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: _Nav.hover,
          onTap: onTap,
          child: tile,
        ),
      ),
    );
  }
}