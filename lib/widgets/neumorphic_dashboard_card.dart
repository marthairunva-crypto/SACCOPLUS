import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/modern_theme.dart';
import 'neumorphic_container.dart';

/// Neumorphic Dashboard Card - Soft UI card for displaying stats
class NeumorphicDashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const NeumorphicDashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon container with subtle inset
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ModernTheme.neumorphicBase,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: ModernTheme.neumorphicShadowInset,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: iconColor ?? ModernTheme.primary,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ModernTheme.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          // Value
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              color: ModernTheme.textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: ModernTheme.textHint,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Neumorphic Action Card - For clickable action items
class NeumorphicActionCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? badge;

  const NeumorphicActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.badge,
  });

  @override
  State<NeumorphicActionCard> createState() => _NeumorphicActionCardState();
}

class _NeumorphicActionCardState extends State<NeumorphicActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: NeumorphicContainer(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(18),
        isPressed: _isPressed,
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (widget.iconColor ?? ModernTheme.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                size: 24,
                color: widget.iconColor ?? ModernTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: ModernTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ModernTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Badge or arrow
            if (widget.badge != null)
              widget.badge!
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: ModernTheme.textHint,
              ),
          ],
        ),
      ),
    );
  }
}

/// Neumorphic Section Header
class NeumorphicSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const NeumorphicSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: ModernTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Neumorphic List Tile - For use in lists
class NeumorphicListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const NeumorphicListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Neumorphic Badge - For notifications or counts
class NeumorphicBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;

  const NeumorphicBadge({
    super.key,
    required this.text,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? ModernTheme.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: (color ?? ModernTheme.primary).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.white,
        ),
      ),
    );
  }
}

/// Neumorphic Tab - For custom tab bars
class NeumorphicTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const NeumorphicTab({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: ModernTheme.neumorphicBase,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? ModernTheme.neumorphicShadowInset
              : ModernTheme.neumorphicShadowSubtle,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? ModernTheme.primary : ModernTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
