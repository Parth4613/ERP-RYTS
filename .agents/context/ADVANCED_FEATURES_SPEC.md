# Advanced Features Specification — Phase 15

> Covers: QR Code, Barcode, Geo-tagging, Daily Progress Reports,
> Equipment & Vehicle Tracking, WhatsApp PDF Sharing, Site Photos.
> These are the MISSING table specs for MODULE_MAP.md Advanced Features section.

---

## Equipment & Vehicle Tracking

### Tables

#### `equipment`
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| equipment_code | text unique | Auto: `EQ-NNN` |
| name | text not null | e.g. "JCB Excavator", "Compressor 100CFM" |
| category | text | excavator, crane, compressor, welding, pump, other |
| owned_or_rented | text | owned, rented |
| supplier_id | bigint → suppliers | if rented, index |
| daily_rent | numeric(15,2) | if rented |
| current_project_id | bigint → projects | nullable, index |
| status | text | idle, deployed, maintenance, retired |
| + standard audit cols | | |

#### `equipment_usage`
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| equipment_id | bigint not null → equipment | index |
| project_id | bigint not null → projects | index |
| zone_id | bigint → project_zones | index |
| usage_date | date not null | |
| hours_used | numeric(5,2) | |
| operator_id | uuid → auth.users | engineer/operator |
| fuel_consumed | numeric(10,2) | litres, if applicable |
| notes | text | |
| + standard audit cols | | |

#### `vehicles`
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| vehicle_number | text unique | registration number |
| vehicle_type | text | truck, pickup, tempo, car |
| owned_or_rented | text | owned, rented |
| driver_name | text | |
| current_project_id | bigint → projects | nullable, index |
| + standard audit cols | | |

#### `diesel_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| vehicle_id | bigint → vehicles | nullable, index |
| equipment_id | bigint → equipment | nullable, index |
| project_id | bigint not null → projects | index |
| log_date | date not null | |
| quantity_litres | numeric(10,2) not null | |
| rate_per_litre | numeric(10,2) | |
| total_cost | numeric(15,2) | computed |
| recorded_by | uuid → auth.users | |
| + standard audit cols | | |

### Business Rules
- BR-ADV-001: Equipment usage hours cannot exceed 24 per day
- BR-ADV-002: Diesel log must reference either vehicle_id or equipment_id (not both null)
- BR-ADV-003: Diesel cost auto-calculated: quantity × rate

### RLS
- Admin: full access
- Owner: read all
- Engineer: create/read own project entries
- Store: read only
- Purchase: no access

### Screens
- Equipment list (status chip, current project, category filter)
- Equipment detail (usage history, fuel consumption, cost summary)
- Daily Usage Entry (equipment + vehicle combined form for engineer)
- Diesel Log form
- Equipment Cost Report per project

---

## Daily Progress Reports

### Table: `daily_progress_reports`

| Column | Type | Notes |
|--------|------|-------|
| id | bigint identity PK | |
| project_id | bigint not null → projects | index |
| zone_id | bigint → project_zones | index |
| report_date | date not null | |
| reported_by | uuid not null → auth.users | engineer, index |
| work_done | text not null | description of work completed |
| manpower_count | int | number of workers on site |
| progress_percentage | numeric(5,2) | overall zone % progress |
| issues_faced | text | blockers, delays, problems |
| next_day_plan | text | planned work for tomorrow |
| weather_condition | text | sunny, cloudy, rain, storm |
| site_photos | text[] | array of Storage URLs |
| pdf_url | text | generated PDF URL |
| status | text | draft, submitted |
| + standard audit cols | | |

**Unique constraint:** `(project_id, zone_id, report_date, reported_by)` — one DPR per engineer per zone per day

### Business Rules
- BR-ADV-004: DPR can only be submitted for today's date or yesterday (no future dates)
- BR-ADV-005: DPR report_date cannot be more than 7 days in the past
- BR-ADV-006: progress_percentage must be between 0 and 100

### RLS
- Admin: full access
- Owner: read all
- Engineer: create own, read own projects
- Store: no access
- Purchase: no access

### DPR PDF Contents
- Company header
- Project + Zone name
- Date + Engineer name
- Work Done section
- Manpower Count
- Progress % (with visual progress bar)
- Issues & Next Day Plan
- Site Photos (thumbnail grid, max 6)
- Signature line

### Screens
- DPR list per project (filterable by date, zone, engineer)
- DPR create form (engineer mobile — optimized for quick entry)
- DPR detail view
- DPR PDF preview + WhatsApp share
- DPR calendar view (heatmap showing which days have reports)

---

## QR Code Integration

### QR Per Material Per Warehouse

```dart
// Generate QR code for a material-warehouse combination
// Package: qr_flutter

Widget buildMaterialQr(int materialId, int warehouseId) {
  final payload = jsonEncode({
    'type': 'material_stock',
    'material_id': materialId,
    'warehouse_id': warehouseId,
  });

  return QrImageView(
    data: payload,
    version: QrVersions.auto,
    size: 200.0,
  );
}
```

### QR Scan → Navigate

```dart
// Package: mobile_scanner

class QrScannerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MobileScanner(
      onDetect: (capture) {
        final barcode = capture.barcodes.first;
        final raw = barcode.rawValue;
        if (raw == null) return;

        try {
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          switch (payload['type']) {
            case 'material_stock':
              context.push('/inventory/stock/${payload['material_id']}');
            case 'issue_slip':
              context.push('/inventory/issuances/${payload['entity_id']}');
            default:
              // Unknown QR
          }
        } catch (e) {
          // Not a Gas Pipeline ERP QR code
        }
      },
    );
  }
}
```

### QR Print Workflow
1. Store generates QR for each material per warehouse
2. QR printed on label and stuck on shelf/bin
3. Any user scans QR → opens material detail instantly
4. Issue slip QR printed on slip → engineer scans to verify/view digitally

---

## Barcode Scanning (MRN)

```dart
// On MRN create screen — scan supplier barcode to auto-fill material

class MrnBarcodeSearch extends ConsumerWidget {
  Future<void> _scanBarcode(WidgetRef ref) async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScanScreen()),
    );

    if (barcode != null) {
      // Search material by barcode/HSN code
      final material = await ref
          .read(materialRepositoryProvider)
          .findByBarcode(barcode);

      if (material != null) {
        // Auto-fill material field in MRN form
        ref.read(mrnFormProvider.notifier).setMaterial(material);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Material not found for barcode: $barcode')),
        );
      }
    }
  }
}
```

**DB Support:** Add `barcode` column to `materials` table:
```sql
ALTER TABLE public.materials ADD COLUMN barcode text;
CREATE INDEX idx_materials_barcode ON public.materials(barcode)
  WHERE barcode IS NOT NULL;
```

---

## Geo-Tagging (MRN / DPR)

```dart
// Capture GPS coordinates on MRN creation
// Package: geolocator

Future<Position?> getCurrentLocation() async {
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }

  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

**DB Support:** Add geo columns to `mrn_headers` and `daily_progress_reports`:
```sql
ALTER TABLE public.mrn_headers
  ADD COLUMN latitude  numeric(10, 7),
  ADD COLUMN longitude numeric(10, 7);

ALTER TABLE public.daily_progress_reports
  ADD COLUMN latitude  numeric(10, 7),
  ADD COLUMN longitude numeric(10, 7);
```

---

## Site Photos

```dart
// Engineer uploads photo with consumption entry or DPR
// Package: image_picker

Future<String?> uploadSitePhoto(int projectId, int? zoneId) async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1920,
    maxHeight: 1080,
    imageQuality: 80,
  );

  if (image == null) return null;

  final file = File(image.path);
  final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';

  final url = await ref.read(storageServiceProvider)
      .uploadSitePhoto(file, projectId, zoneId, filename);

  return url;
}
```

Storage path: See `SUPABASE_STORAGE_STRUCTURE.md` → Site Photos section.

---

## WhatsApp PDF Sharing

```dart
// Any PDF (issue slip, report, DPR) can be shared
// Packages: share_plus, url_launcher

// Option 1: share_plus (system share sheet, includes WhatsApp if installed)
Future<void> shareViaPlatform(Uint8List pdfBytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(pdfBytes);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    text: 'Please find attached: $filename',
    subject: filename,
  );
}

// Option 2: direct WhatsApp deep link (opens WA directly)
Future<void> shareViaWhatsApp(String phoneNumber, String message) async {
  final encoded = Uri.encodeComponent(message);
  final url = 'https://wa.me/$phoneNumber?text=$encoded';
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

---

## Migration File Reference

All Advanced Features belong in **phase15_advanced.sql**:

```
Tables to create:
  - equipment
  - equipment_usage
  - vehicles
  - diesel_logs
  - daily_progress_reports

Column additions:
  - materials.barcode
  - mrn_headers.latitude, longitude
  - daily_progress_reports.latitude, longitude

Sequences to create:
  - seq_equipment_number

Triggers:
  - equipment set_code trigger
  - daily_progress_reports date validation trigger (BR-ADV-004, BR-ADV-005)
  - diesel_logs total_cost auto-calculate trigger (BR-ADV-003)
```
