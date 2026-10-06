import 'package:flutter/material.dart';
import '../theme/modern_theme.dart';

/// Reusable Neumorphic Container Widget
/// Provides soft UI effect with customizable properties
class NeumorphicContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final bool isPressed;
  final VoidCallback? onTap;
  final AlignmentGeometry? alignment;

  const NeumorphicContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.isPressed = false,
    this.onTap,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? ModernTheme.neumorphicBase,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      boxShadow: isPressed
          ? ModernTheme.neumorphicShadowInset
          : ModernTheme.neumorphicShadow,
    );

    final container = Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      alignment: alignment,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

/// Neumorphic Card - Elevated soft card
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeumorphicContainer(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.all(8),
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      onTap: onTap,
      child: child,
    );
  }
}

/// Neumorphic Button - Soft interactive button
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
    this.borderRadius,
    this.color,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: NeumorphicContainer(
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
        color: widget.color,
        isPressed: _isPressed,
        child: widget.child,
      ),
    );
  }
}

/// Neumorphic Icon Button
class NeumorphicIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 24,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: NeumorphicContainer(
        width: widget.size + 32,
        height: widget.size + 32,
        borderRadius: BorderRadius.circular(14),
        color: widget.backgroundColor,
        isPressed: _isPressed,
        alignment: Alignment.center,
        child: Icon(
          widget.icon,
          size: widget.size,
          color: widget.iconColor ?? ModernTheme.textPrimary,
        ),
      ),
    );
  }
}

/// Neumorphic Text Field - Soft input field
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int? maxLines;
  final bool enabled;

  const NeumorphicTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: ModernTheme.neumorphicShadowInset,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        validator: validator,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: ModernTheme.neumorphicBase,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ModernTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Neumorphic Progress Indicator
class NeumorphicProgressIndicator extends StatelessWidget {
  final double value;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final BorderRadius? borderRadius;

  const NeumorphicProgressIndicator({
    super.key,
    required this.value,
    this.height = 12,
    this.backgroundColor,
    this.progressColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? ModernTheme.neumorphicBase,
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        boxShadow: ModernTheme.neumorphicShadowInset,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      progressColor ?? ModernTheme.primary,
                      (progressColor ?? ModernTheme.primary).withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neumorphic Divider
class NeumorphicDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const NeumorphicDivider({
    super.key,
    this.height = 1,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }
}
