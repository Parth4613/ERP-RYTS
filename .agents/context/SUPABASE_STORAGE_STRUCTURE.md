# Supabase Storage Structure

> All file uploads go to Supabase Storage.
> Agents use these exact bucket names and path patterns.

---

## Buckets

| Bucket | Public? | Purpose |
|--------|---------|---------|
| `issue-slips` | No | Generated Issue Slip PDFs |
| `project-documents` | No | Drawings, BOQ files, agreements, invoices |
| `site-photos` | No | Daily progress photos from engineers |
| `mrn-attachments` | No | Delivery challans, invoices scanned |
| `reports` | No | Generated report PDFs / Excel files |
| `avatars` | Yes | User profile pictures |

---

## Path Conventions

### Issue Slips
```
issue-slips/
  {year}/
    {slip_number}.pdf
    e.g. 2024/IS-2024-0042.pdf
```

### Project Documents
```
project-documents/
  {project_id}/
    {category}/
      {original_filename}
      e.g. 1042/drawings/site-layout-v2.pdf
           1042/agreements/main-contract.pdf
           1042/test-reports/pressure-test-zone-a.pdf
```

### Site Photos
```
site-photos/
  {project_id}/
    {zone_id}/
      {YYYY-MM-DD}/
        {timestamp}_{original_filename}
        e.g. 1042/3/2024-03-15/14-32-05_pipe-welding.jpg
```

### MRN Attachments
```
mrn-attachments/
  {mrn_number}/
    dc_{dc_number}.pdf
    invoice_{invoice_number}.pdf
```

### Reports
```
reports/
  {report_type}/
    {year}/
      {timestamp}_{filter_description}.pdf
      e.g. inventory/2024/20240315-144532_all-warehouses.pdf
           costs/2024/20240315-144532_project-1042.xlsx
```

---

## Flutter Storage Service

```dart
// core/services/storage_service.dart

class StorageService {
  final SupabaseStorageClient _storage;

  StorageService(SupabaseClient client) : _storage = client.storage;

  // Upload issue slip PDF
  Future<String> uploadIssueSlipPdf(Uint8List bytes, String slipNumber) async {
    final year = DateTime.now().year.toString();
    final path = '$year/$slipNumber.pdf';
    await _storage.from('issue-slips').uploadBinary(
      path, bytes,
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );
    return _storage.from('issue-slips').getPublicUrl(path);
    // Note: for private buckets use createSignedUrl instead
  }

  // Get signed URL for private file (1 hour expiry)
  Future<String> getSignedUrl(String bucket, String path) async {
    return _storage.from(bucket).createSignedUrl(path, 3600);
  }

  // Upload site photo
  Future<String> uploadSitePhoto(
    File photo, int projectId, int? zoneId, String filename,
  ) async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ts = DateFormat('HH-mm-ss').format(DateTime.now());
    final zone = zoneId?.toString() ?? 'general';
    final path = '$projectId/$zone/$date/${ts}_$filename';

    await _storage.from('site-photos').upload(
      path, photo,
      fileOptions: const FileOptions(upsert: false),
    );
    return path; // store path, generate signed URL on demand
  }

  // Upload project document
  Future<String> uploadProjectDocument(
    File file, int projectId, String category, String filename,
  ) async {
    final path = '$projectId/$category/$filename';
    await _storage.from('project-documents').upload(path, file);
    return path;
  }
}
```

---

## RLS on Storage Buckets

Configure via Supabase Dashboard → Storage → Policies:

```sql
-- issue-slips: store and admin can upload; all authenticated can read
CREATE POLICY "issue_slips_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'issue-slips');

CREATE POLICY "issue_slips_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'issue-slips'
    AND (auth.jwt()->'app_metadata'->>'role') IN ('admin','store')
  );

-- project-documents: project members upload; project members read
CREATE POLICY "project_docs_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'project-documents');

CREATE POLICY "project_docs_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'project-documents');

-- site-photos: engineers upload; owner/admin/engineer read
CREATE POLICY "site_photos_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'site-photos'
    AND (auth.jwt()->'app_metadata'->>'role') IN ('admin','engineer')
  );

CREATE POLICY "site_photos_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'site-photos');
```