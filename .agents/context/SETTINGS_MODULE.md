# Settings Module — app_settings Table

> The `app_settings` table is referenced in DECISIONS.md (AD-022) and in BUSINESS_RULES_SQL.md
> for configurable approval thresholds. This file fully specifies the Settings module.
> Agents building Phase 1 foundation MUST create the app_settings table.

---

## Purpose

A key-value store for system-wide configurable parameters.
Used by DB triggers (BR-025, BR-026) and the Flutter Settings screen.

---

## Table: `app_settings`

| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| key | text not null unique | e.g. `approval_threshold_po` |
| value | text not null | all stored as text, cast in code |
| description | text | human readable explanation |
| data_type | text | `number`, `text`, `boolean`, `date` |
| is_editable | boolean default true | some settings are read-only |
| + standard audit cols | | |

---

## Default Settings (Seed Data)

```sql
INSERT INTO public.app_settings (key, value, description, data_type) VALUES
  ('approval_threshold_po',  '500000', 'PO value (₹) above which Owner approval is required', 'number'),
  ('approval_threshold_pr',  '50000',  'PR value (₹) above which Owner approval is required', 'number'),
  ('company_name',           'Gas Pipeline Installation Co.', 'Company name for PDFs and reports', 'text'),
  ('company_gstin',          '',       'Company GSTIN for invoices', 'text'),
  ('company_address',        '',       'Company address for PDFs', 'text'),
  ('company_logo_url',       '',       'Supabase Storage URL for company logo in PDFs', 'text'),
  ('low_stock_alert_enabled','true',   'Enable low stock alerts in dashboard', 'boolean'),
  ('boq_overrun_threshold',  '80',     'Alert when BOQ consumption exceeds this % of planned', 'number'),
  ('wastage_alert_threshold','5',      'Alert when project wastage exceeds this % of issued', 'number'),
  ('financial_year_start',   '04',     'Month number (01-12) when financial year starts', 'number');
```

---

## RLS

```sql
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings FORCE ROW LEVEL SECURITY;

-- All authenticated users can read settings
CREATE POLICY "settings_read_all" ON public.app_settings
  FOR SELECT TO authenticated
  USING (true);

-- Only admin can write settings
CREATE POLICY "settings_admin_write" ON public.app_settings
  FOR ALL TO authenticated
  USING ((select auth.jwt()->'app_metadata'->>'role') = 'admin')
  WITH CHECK ((select auth.jwt()->'app_metadata'->>'role') = 'admin');
```

---

## Flutter: SettingsRepository

```dart
// features/settings/data/repositories/settings_repository_impl.dart

class SettingsRepository {
  final SupabaseClient _client;
  SettingsRepository(this._client);

  Future<Map<String, String>> getAll() async {
    final data = await _client
        .from('app_settings')
        .select('key, value')
        .isFilter('deleted_at', null);
    return {for (var row in data) row['key'] as String: row['value'] as String};
  }

  Future<String?> get(String key) async {
    final data = await _client
        .from('app_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return data?['value'] as String?;
  }

  Future<double> getThreshold(String entityType) async {
    final value = await get('approval_threshold_$entityType');
    return double.tryParse(value ?? '') ?? 500000.0;
  }

  Future<void> update(String key, String value) async {
    await _client
        .from('app_settings')
        .update({'value': value, 'updated_by': _client.auth.currentUser?.id})
        .eq('key', key);
  }
}
```

---

## Flutter: SettingsProvider

```dart
// features/settings/presentation/providers/settings_provider.dart

@riverpod
Future<Map<String, String>> allSettings(AllSettingsRef ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getAll();
}

@riverpod
Future<double> poApprovalThreshold(PoApprovalThresholdRef ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getThreshold('po');
}

@riverpod
Future<double> prApprovalThreshold(PrApprovalThresholdRef ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getThreshold('pr');
}
```

---

## Flutter: Settings Screen (Admin Only)

```
Screens:
  - SettingsListScreen (shows all editable settings grouped by category)
  - EditSettingScreen (edit a single setting value with type-appropriate input)

Screen Groups:
  1. Company Info
     - Company Name
     - GSTIN
     - Address
     - Logo (image picker → Supabase Storage upload)
  2. Approval Thresholds
     - PO Approval Threshold (₹)
     - PR Approval Threshold (₹)
  3. Alerts
     - BOQ Overrun Threshold (%)
     - Wastage Alert Threshold (%)
     - Low Stock Alerts (toggle)
  4. Financial
     - Financial Year Start Month
```

---

## Helper: Reading Settings in DB Triggers

The `check_approval_required()` function in BUSINESS_RULES_SQL.md
reads from this table:

```sql
-- Already defined in BUSINESS_RULES_SQL.md
SELECT p_amount > COALESCE(
  (SELECT value::NUMERIC FROM public.app_settings
   WHERE key = 'approval_threshold_' || p_entity_type),
  500000  -- fallback default if setting not seeded
);
```

Make sure `app_settings` is seeded with the INSERT above
**before** running any procurement triggers.

---

## Migration Note

The `app_settings` table belongs in **phase1_foundation.sql**.
It must be created and seeded before any other migrations run,
because phase8_procurement.sql triggers reference it.
