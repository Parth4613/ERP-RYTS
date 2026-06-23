# Realtime Subscriptions

> Only subscribe to tables that genuinely need live updates.
> Over-subscribing wastes connections. See AD-025.

---

## Active Subscriptions Per Role

| Table | Roles That Subscribe | Event | Purpose |
|-------|---------------------|-------|---------|
| `notifications` | All | INSERT | Show in-app alerts instantly |
| `material_requests` | store, engineer | INSERT, UPDATE | MR status changes |
| `approval_workflows` | owner, admin | INSERT | New items need approval |
| `stock_balances` | store, admin | UPDATE | Low-stock alert trigger |
| `purchase_orders` | purchase, store | UPDATE | Delivery status changes |
| `issue_slips` | engineer | INSERT | Engineer sees when goods issued |

All other tables: use pull-to-refresh or `ref.invalidate()` after actions.

---

## Flutter Implementation Pattern

```dart
// In BaseRepository — stream() method
@override
Stream<List<T>> watchAll({String orderBy = 'created_at'}) {
  return client
      .from(tableName)
      .stream(primaryKey: ['id'])
      .order(orderBy, ascending: false)
      .map((rows) => rows
          .where((r) => r['deleted_at'] == null)
          .map(fromJson)
          .toList());
}

// Filtered stream (e.g. pending MRs for store)
Stream<List<MaterialRequestModel>> watchByStatus(List<String> statuses) {
  return client
      .from('material_requests')
      .stream(primaryKey: ['id'])
      .inFilter('status', statuses)
      .order('created_at', ascending: false)
      .map((rows) => rows.map((r) => MaterialRequestModel.fromJson(r)).toList());
}
```

```dart
// In Riverpod provider — stream provider
@riverpod
Stream<List<NotificationModel>> notificationStream(NotificationStreamRef ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map((r) => NotificationModel.fromJson(r)).toList());
}

// Unread count badge
@riverpod
int unreadNotificationCount(UnreadNotificationCountRef ref) {
  final notifications = ref.watch(notificationStreamProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
}
```

---

## Notification Model

```dart
@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required int id,
    required String userId,
    required String type,
    required String title,
    required String message,
    String? entityType,
    int? entityId,
    @Default(false) bool isRead,
    required DateTime createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
```

---

## Notification Types & Deep-Link Routes

| type | title template | Go Router route on tap |
|------|----------------|----------------------|
| `approval_required` | "Approval Required: MR" | `/material-requests/:id` |
| `mr_approved` | "MR-2024-0042 Approved" | `/material-requests/:id` |
| `mr_rejected` | "MR-2024-0042 Rejected" | `/material-requests/:id` |
| `low_stock` | "Low Stock: HDPE Pipe 63mm" | `/inventory/stock/:material_id` |
| `po_overdue` | "PO-2024-0018 Delivery Overdue" | `/procurement/po/:id` |
| `boq_overrun` | "BOQ Warning: Project Alpha" | `/projects/:id/boq` |
| `mr_issued` | "MR-2024-0042 Fully Issued" | `/material-requests/:id` |

---

## Notification Bell Widget

```dart
// core/widgets/notification_bell.dart
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
        ),
        if (count > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
```