# Neumorphic (Soft UI) Design Guide for MBADIFA SACCO

This guide explains how to implement the new neumorphic (soft surface) UI throughout the application.

## What is Neumorphism?

Neumorphism is a modern UI design trend that creates a "soft" 3D effect by using:
- Subtle shadows (light from top-left, dark from bottom-right)
- Minimal color contrast
- Elements that appear to be extruded from or pressed into the background
- Soft, rounded corners

## Color Palette

Base Background: `#E8EDF2` (light gray-blue)
- This is the foundation for the neumorphic effect
- Used as the main app background and card base

## Core Components

### 1. NeumorphicContainer
Basic building block for all neumorphic elements.

```dart
import 'package:agri_loan/widgets/neumorphic_container.dart';

NeumorphicContainer(
  padding: EdgeInsets.all(20),
  borderRadius: BorderRadius.circular(16),
  child: Text('Content here'),
)
```

**Properties:**
- `isPressed: true` - For inset/pressed effect
- `color` - Background color (defaults to neumorphicBase)
- `onTap` - Makes it tappable
- `borderRadius` - Corner radius

### 2. NeumorphicCard
Pre-configured card for content sections.

```dart
NeumorphicCard(
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      Text('Title'),
      Text('Content'),
    ],
  ),
)
```

### 3. NeumorphicButton
Interactive button with press effect.

```dart
NeumorphicButton(
  onPressed: () {
    // Handle tap
  },
  child: Text(
    'Click Me',
    style: TextStyle(fontWeight: FontWeight.w600),
  ),
)
```

### 4. NeumorphicIconButton
Circular icon button with soft shadows.

```dart
NeumorphicIconButton(
  icon: Icons.add,
  iconColor: Colors.blue,
  size: 24,
  onPressed: () {
    // Handle tap
  },
)
```

### 5. NeumorphicTextField
Input field with inset effect.

```dart
NeumorphicTextField(
  labelText: 'Enter amount',
  hintText: 'e.g., 100,000',
  controller: controller,
  keyboardType: TextInputType.number,
  prefixIcon: Icon(Icons.attach_money),
)
```

### 6. NeumorphicProgressIndicator
Progress bar with soft styling.

```dart
NeumorphicProgressIndicator(
  value: 0.65, // 0.0 to 1.0
  height: 12,
  progressColor: Colors.green,
)
```

## Dashboard Components

### NeumorphicDashboardCard
For displaying statistics and metrics.

```dart
import 'package:agri_loan/widgets/neumorphic_dashboard_card.dart';

NeumorphicDashboardCard(
  title: 'Total Members',
  value: '1,234',
  icon: Icons.people,
  iconColor: Colors.blue,
  subtitle: '+12 this month',
  onTap: () {
    // Navigate to members
  },
)
```

### NeumorphicActionCard
For clickable menu items.

```dart
NeumorphicActionCard(
  title: 'Loan Applications',
  subtitle: 'Review pending requests',
  icon: Icons.description,
  iconColor: Colors.orange,
  badge: NeumorphicBadge(text: '5'),
  onTap: () {
    // Navigate to loans
  },
)
```

### NeumorphicSectionHeader
For section titles.

```dart
NeumorphicSectionHeader(
  title: 'Quick Actions',
  subtitle: 'Common tasks',
  action: TextButton(
    onPressed: () {},
    child: Text('View All'),
  ),
)
```

### NeumorphicListTile
For list items.

```dart
NeumorphicListTile(
  leading: Icon(Icons.person),
  title: 'John Doe',
  subtitle: 'Account: 12345',
  trailing: Icon(Icons.chevron_right),
  onTap: () {},
)
```

## Using Theme Shadows Directly

If you need custom containers, use the theme shadows:

```dart
import 'package:agri_loan/theme/modern_theme.dart';

Container(
  decoration: BoxDecoration(
    color: ModernTheme.neumorphicBase,
    borderRadius: BorderRadius.circular(16),
    boxShadow: ModernTheme.neumorphicShadow, // Raised effect
    // OR
    boxShadow: ModernTheme.neumorphicShadowInset, // Pressed effect
    // OR
    boxShadow: ModernTheme.neumorphicShadowSubtle, // Subtle raised
  ),
  child: content,
)
```

## Helper Methods

### ModernTheme.neumorphicDecoration()
```dart
Container(
  decoration: ModernTheme.neumorphicDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
  ),
)
```

### ModernTheme.neumorphicDecorationInset()
```dart
// For pressed/inset effect
Container(
  decoration: ModernTheme.neumorphicDecorationInset(),
)
```

## Best Practices

### 1. Use Consistent Spacing
```dart
// Standard padding for cards
padding: EdgeInsets.all(16)
padding: EdgeInsets.all(20)

// Standard margins
margin: EdgeInsets.all(8)
margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8)
```

### 2. Border Radius
- Small elements: `12-14px`
- Cards: `16-18px`
- Large containers: `20px`

### 3. Icon Sizes
- Small icons: `20-24px`
- Standard icons: `24-28px`
- Large icons: `32-36px`

### 4. Shadows
- Use `neumorphicShadow` for raised elements (cards, buttons)
- Use `neumorphicShadowInset` for pressed elements (text fields, pressed buttons)
- Use `neumorphicShadowSubtle` for less prominent elements

### 5. Colors
- Keep most UI elements at base color `#E8EDF2`
- Use colored accents sparingly (icons, progress bars, badges)
- Text should have good contrast (use `ModernTheme.textPrimary`)

## Example: Converting Existing Cards

### Before (Flat Material)
```dart
Card(
  elevation: 2,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Icon(Icons.wallet, color: Colors.blue),
        Text('Balance'),
        Text('\$1,000'),
      ],
    ),
  ),
)
```

### After (Neumorphic)
```dart
NeumorphicDashboardCard(
  icon: Icons.wallet,
  iconColor: Colors.blue,
  title: 'Balance',
  value: '\$1,000',
)
```

## Grid Layouts

For dashboard grids:

```dart
GridView.count(
  crossAxisCount: 2,
  childAspectRatio: 1.3,
  padding: EdgeInsets.all(8),
  children: [
    NeumorphicDashboardCard(
      title: 'Members',
      value: '1,234',
      icon: Icons.people,
      iconColor: Colors.blue,
    ),
    NeumorphicDashboardCard(
      title: 'Loans',
      value: '456',
      icon: Icons.receipt,
      iconColor: Colors.green,
    ),
    // More cards...
  ],
)
```

## Teller Card Layout

For the teller screen cards (4 columns):

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    childAspectRatio: 1.5,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  ),
  padding: EdgeInsets.all(16),
  itemCount: items.length,
  itemBuilder: (context, index) {
    return NeumorphicActionCard(
      title: items[index].title,
      icon: items[index].icon,
      iconColor: items[index].color,
      onTap: () => _handleAction(items[index]),
    );
  },
)
```

## Typography

Use Inter font (already configured in theme):

```dart
import 'package:google_fonts/google_fonts.dart';

Text(
  'Title',
  style: GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: ModernTheme.textPrimary,
    letterSpacing: -0.3,
  ),
)

Text(
  'Subtitle',
  style: GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ModernTheme.textSecondary,
  ),
)
```

## AppBar

AppBar now uses neumorphic background:

```dart
AppBar(
  backgroundColor: ModernTheme.neumorphicBase,
  foregroundColor: ModernTheme.textPrimary,
  elevation: 0,
  title: Text('Dashboard'),
)
```

## Scaffold Background

```dart
Scaffold(
  backgroundColor: ModernTheme.neumorphicBase,
  appBar: AppBar(...),
  body: ...,
)
```

## Notes

1. **Hot Restart Required**: After adding neumorphic widgets to existing screens, do a Hot Restart (not just Hot Reload) to see changes properly.

2. **Accessibility**: Neumorphism can have low contrast. Ensure text has sufficient contrast (use `ModernTheme.textPrimary` for important text).

3. **Performance**: Shadows are GPU-intensive. On older devices, consider using `neumorphicShadowSubtle` instead of full shadows.

4. **Consistency**: Use the provided components rather than creating custom shadows for consistency across the app.

## Migration Checklist

When updating a screen to neumorphic UI:

- [ ] Replace `Card` with `NeumorphicCard` or `NeumorphicContainer`
- [ ] Replace `ElevatedButton` with `NeumorphicButton` (or keep for primary actions with color)
- [ ] Replace `IconButton` with `NeumorphicIconButton`
- [ ] Replace `TextFormField` with `NeumorphicTextField` (or keep default theme)
- [ ] Update background color to `ModernTheme.neumorphicBase`
- [ ] Update text styles to use Inter font
- [ ] Use dashboard components for stat cards
- [ ] Test on device after Hot Restart

## Need Help?

Check existing implementations in:
- `lib/widgets/neumorphic_container.dart` - Base components
- `lib/widgets/neumorphic_dashboard_card.dart` - Dashboard components
- `lib/theme/modern_theme.dart` - Theme configuration
