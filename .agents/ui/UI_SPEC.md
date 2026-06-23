UI Specification — Gas Pipeline ERP

> Every Flutter screen follows this spec. Do not invent alternative themes or components.
> The app must feel like a ₹50 lakh custom enterprise platform.

---

## Design Philosophy

Inspired by: **Linear + Stripe Dashboard + Notion + Monday.com**

Goals:
- Premium, data-dense, professional
- Mobile-first (engineers use on-site)
- Dark theme by default (readability in sunlight)
- Fast navigation, minimal taps
- Role-specific dashboards (what you see = what your role needs)

---

## Color Tokens (app_colors.dart)

```dart
class AppColors {
  // Backgrounds
  static const background   = Color(0xFF0F1117); // page background
  static const surface      = Color(0xFF171A21); // cards, sheets
  static const surfaceAlt   = Color(0xFF1F2430); // elevated cards
  static const border       = Color(0xFF2D3443); // dividers, outlines

  // Brand
  static const primary      = Color(0xFF4F8CFF); // actions, links, active
  static const primaryDim   = Color(0xFF1E3A6E); // primary backgrounds

  // Semantic
  static const success      = Color(0xFF22C55E);
  static const successDim   = Color(0xFF14532D);
  static const warning      = Color(0xFFF59E0B);
  static const warningDim   = Color(0xFF78350F);
  static const danger       = Color(0xFFEF4444);
  static const dangerDim    = Color(0xFF7F1D1D);
  static const info         = Color(0xFF06B6D4);
  static const infoDim      = Color(0xFF164E63);

  // Text
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF64748B);

  // Status chips (consistent across all modules)
  static statusColor(String status) => switch(status) {
    'active' || 'approved' || 'completed' || 'fully_issued' => success,
    'draft' || 'planning'                                    => textMuted,
    'submitted' || 'pending' || 'ordered'                   => warning,
    'partially_issued' || 'partially_received'              => info,
    'on_hold' || 'rejected'                                 => danger,
    'closed'                                                 => textSecondary,
    _ => textMuted,
  };
}
```

---

## Typography (app_text_styles.dart)

```dart
class AppTextStyles {
  // KPI values on dashboard
  static const kpiValue = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );

  // Page titles
  static const pageTitle = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Section headers
  static const sectionTitle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, letterSpacing: 0.5,
  );

  // Body text
  static const body = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const bodySmall = TextStyle(fontSize: 12, color: AppColors.textSecondary);

  // Table cells
  static const tableCell = TextStyle(fontSize: 13, color: AppColors.textPrimary);
  static const tableHeader = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textSecondary, letterSpacing: 0.8,
  );

  // Currency (₹ amounts)
  static const currency = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, fontFeatures: [FontFeature.tabularFigures()],
  );
}
```

---

## ThemeData Configuration

```dart
ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    background: AppColors.background,
    surface: AppColors.surface,
    primary: AppColors.primary,
    error: AppColors.danger,
    onBackground: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
    outline: AppColors.border,
  ),
  scaffoldBackgroundColor: AppColors.background,
  cardTheme: CardTheme(
    color: AppColors.surfaceAlt,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.border, width: 1),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.surface,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: AppTextStyles.pageTitle,
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary),
    hintStyle: TextStyle(color: AppColors.textMuted),
  ),
  dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textMuted,
  ),
);
```

---

## Navigation Structure

### Mobile — Bottom Navigation Bar
```
Dashboard | Projects | Inventory | Procurement | More
```
"More" → side drawer for: Reports, Documents, Suppliers, Settings

### Desktop — Left Sidebar (NavigationRail)
```
Dashboard
Projects
BOQ
Material Requests
Inventory
Procurement
Suppliers
MRN
Cost Tracking
Documents
Reports
Settings
```

### Go Router Shell Structure
```dart
ShellRoute (scaffold with bottom nav)
  ├── /dashboard
  ├── /projects
  │   ├── /projects/:id
  │   ├── /projects/:id/boq
  │   ├── /projects/:id/material-requests
  │   ├── /projects/:id/costs
  │   └── /projects/:id/zones
  ├── /inventory
  │   ├── /inventory/stock
  │   ├── /inventory/transactions
  │   └── /inventory/adjustments
  ├── /material-requests
  │   └── /material-requests/:id
  ├── /procurement
  │   ├── /procurement/pr
  │   ├── /procurement/pr/:id
  │   ├── /procurement/po
  │   └── /procurement/po/:id
  ├── /suppliers
  │   └── /suppliers/:id
  ├── /mrn
  │   └── /mrn/:id
  ├── /reports
  ├── /documents
  └── /settings
```

---

## Reusable Components (core/widgets/)

### AppCard
```dart
// Elevated card with consistent styling
AppCard({
  required Widget child,
  VoidCallback? onTap,
  EdgeInsets? padding,
  Color? borderColor,  // highlight color (danger for alerts)
})
```

### KpiCard
```dart
// For dashboard KPI metrics
KpiCard({
  required String title,
  required String value,
  String? subtitle,
  IconData? icon,
  Color? valueColor,
  String? trend,       // "+4%" with color
  VoidCallback? onTap,
})
```

### StatusChip
```dart
// Consistent status across all modules
StatusChip(status: 'approved')  // auto-colors via AppColors.statusColor
```

### ErpDataTable
```dart
// Consistent table for all list screens
ErpDataTable({
  required List<String> columns,
  required List<DataRow> rows,
  required TextEditingController searchController,
  required List<String> activeFilters,
  required VoidCallback onExport,
  bool showPagination = true,
})
```

### EmptyState
```dart
EmptyState({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? action,  // e.g. "Create First Project" button
})
```

### LoadingSkeleton
```dart
LoadingSkeleton({required int itemCount})  // shimmer loading effect
```

### AppAlertBanner
```dart
// For critical alerts (low stock, overdue PO, BOQ overrun)
AppAlertBanner({
  required String message,
  required AlertLevel level,  // critical, warning, info
  VoidCallback? onTap,
})
```

### ConfirmationDialog
```dart
// For destructive actions
showErpConfirmDialog(
  context: context,
  title: 'Approve Purchase Order?',
  message: 'PO-2024-0042 for ₹1,24,500 will be sent to supplier.',
  confirmLabel: 'Approve',
  onConfirm: () => ref.read(poProvider.notifier).approve(id),
)
```

---

## Screen Layout Pattern

Every list screen follows this structure:

```dart
Scaffold(
  appBar: AppBar(
    title: Text('Material Requests'),
    actions: [
      IconButton(icon: Icon(Icons.filter_list), onPressed: _showFilters),
      IconButton(icon: Icon(Icons.download), onPressed: _export),
    ],
  ),
  body: Column(children: [
    // 1. Search bar
    ErpSearchBar(controller: _search, hint: 'Search by MR number, project...'),

    // 2. Filter chips (horizontal scroll)
    FilterChipRow(filters: ['All', 'Pending', 'Approved', 'Issued']),

    // 3. Summary stats bar (optional)
    StatsBar(items: [('Total', '24'), ('Pending', '8'), ('This Week', '5')]),

    // 4. List content
    Expanded(
      child: ref.watch(mrListProvider).when(
        data: (items) => items.isEmpty
          ? EmptyState(...)
          : ListView.builder(...),
        loading: () => LoadingSkeleton(itemCount: 8),
        error: (e, _) => ErrorState(message: e.toString()),
      ),
    ),
  ]),
  floatingActionButton: FloatingActionButton.extended(
    onPressed: _createMR,
    label: Text('New MR'),
    icon: Icon(Icons.add),
  ),
)
```

---

## Form Pattern

```dart
// All forms use AutovalidateMode.onUserInteraction
// All forms auto-save as draft on exit (where applicable)

// Form fields are organized in sections:
FormSection(
  title: 'Project Details',
  children: [
    ErpDropdown(label: 'Project', items: projects, ...),
    ErpDropdown(label: 'Zone', items: zones, ...),
  ],
),
FormSection(
  title: 'Items',
  children: [
    MaterialItemsTable(items: _items, onAdd: _addItem, onRemove: _removeItem),
  ],
),
FormActions(
  onSaveDraft: _saveDraft,
  onSubmit: _submit,
)
```

---

## Currency Formatting

```dart
// Always use ₹ with Indian number formatting
extension CurrencyFormat on num {
  String get inr => '₹${NumberFormat('#,##,##0.00', 'en_IN').format(this)}';
  String get inrCompact => '₹${NumberFormat.compact(locale: 'en_IN').format(this)}';
  // e.g. 1250000 → "₹12,50,000.00" or "₹12.5L"
}
```

---

## Animation Rules

- Duration: 200–300ms only. Never longer.
- Use `AnimatedSwitcher` for state transitions (loading → data)
- Use `SlideTransition` for new screens (bottom sheet, page push)
- Use `FadeTransition` for content changes
- No heavy transitions. Enterprise = fast, not flashy.

---

## Responsive Breakpoints

```dart
class Breakpoints {
  static const mobile  = 600.0;
  static const tablet  = 900.0;
  static const desktop = 1200.0;
}

// Usage:
LayoutBuilder(builder: (ctx, constraints) {
  if (constraints.maxWidth < Breakpoints.mobile) return MobileLayout();
  if (constraints.maxWidth < Breakpoints.desktop) return TabletLayout();
  return DesktopLayout();
})
```

Mobile: single column, bottom nav
Tablet: 2 columns, bottom nav
Desktop: sidebar + main content (60/40 or 70/30 split)