# Notification System — DB Trigger Spec

> REALTIME_SUBSCRIPTIONS.md covers the Flutter side (subscribing to `notifications`).
> This file covers the DB side: when and how notifications are inserted.
> Agents building Phase 4 (Approvals) and beyond MUST implement these triggers.

---

## Table: `notifications`

Belongs in **phase1_foundation.sql** (created early, used by all phases).

```sql
CREATE TABLE public.notifications (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES auth.users(id),
  type          text NOT NULL,          -- see types below
  title         text NOT NULL,
  message       text NOT NULL,
  entity_type   text,                   -- 'material_request', 'purchase_order', etc.
  entity_id     bigint,                 -- ID of the related record
  is_read       boolean NOT NULL DEFAULT false,
  read_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  -- No updated_at, deleted_at — notifications are immutable (append-only)
  CONSTRAINT notifications_type_check CHECK (type IN (
    'approval_required',
    'mr_approved',
    'mr_rejected',
    'mr_issued',
    'low_stock',
    'po_overdue',
    'boq_overrun',
    'inventory_adjustment_required',
    'mrn_received',
    'system'
  ))
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read  ON public.notifications(user_id, is_read)
  WHERE is_read = false;  -- partial index — only unread
CREATE INDEX idx_notifications_entity   ON public.notifications(entity_type, entity_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

-- Each user reads only their own notifications
CREATE POLICY "notifications_own_read" ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

-- Mark as read (only own)
CREATE POLICY "notifications_own_update" ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- Only SECURITY DEFINER functions insert notifications (not app code directly)
-- No INSERT policy for regular authenticated role
```

---

## Helper: `create_notification()` Function

```sql
-- Generic notification inserter — used by all triggers
-- SECURITY DEFINER: can insert even without INSERT RLS policy on notifications

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id     uuid,
  p_type        text,
  p_title       text,
  p_message     text,
  p_entity_type text DEFAULT NULL,
  p_entity_id   bigint DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, message, entity_type, entity_id)
  VALUES (p_user_id, p_type, p_title, p_message, p_entity_type, p_entity_id);
END;
$$;
```

---

## Helper: `get_users_by_role()` Function

```sql
-- Returns all user IDs with a specific role (reads app_metadata)
-- Used by triggers to notify admin/owner roles

CREATE OR REPLACE FUNCTION public.get_users_by_role(p_role text)
RETURNS TABLE(user_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT id FROM auth.users
  WHERE raw_app_meta_data->>'role' = p_role
    AND deleted_at IS NULL;  -- if users table tracks this
$$;
```

---

## Trigger: MR Submitted → Notify Owner/Admin

```sql
CREATE OR REPLACE FUNCTION public.notify_mr_submitted()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'submitted' AND OLD.status = 'draft' THEN
    -- Notify all admins and owners
    PERFORM public.create_notification(
      u.user_id,
      'approval_required',
      'Approval Required: Material Request',
      FORMAT('MR %s requires your approval.', NEW.mr_number),
      'material_request',
      NEW.id
    )
    FROM public.get_users_by_role('admin') u
    UNION ALL
    SELECT * FROM public.get_users_by_role('owner');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_submitted_notify
  AFTER UPDATE ON public.material_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_mr_submitted();
```

---

## Trigger: MR Approved/Rejected → Notify Requester

```sql
CREATE OR REPLACE FUNCTION public.notify_mr_decision()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status = 'submitted' THEN
    PERFORM public.create_notification(
      NEW.requested_by,
      'mr_approved',
      'Material Request Approved',
      FORMAT('Your MR %s has been approved.', NEW.mr_number),
      'material_request',
      NEW.id
    );
  ELSIF NEW.status = 'rejected' AND OLD.status = 'submitted' THEN
    PERFORM public.create_notification(
      NEW.requested_by,
      'mr_rejected',
      'Material Request Rejected',
      FORMAT('Your MR %s was rejected.', NEW.mr_number),
      'material_request',
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER mr_decision_notify
  AFTER UPDATE ON public.material_requests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_mr_decision();
```

---

## Trigger: Issue Slip Completed → Notify Engineer

```sql
CREATE OR REPLACE FUNCTION public.notify_mr_issued()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_engineer_id uuid;
  v_mr_number   text;
BEGIN
  IF NEW.status = 'complete' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    SELECT mr.requested_by, mr.mr_number
    INTO v_engineer_id, v_mr_number
    FROM public.material_requests mr
    WHERE mr.id = NEW.mr_id;

    PERFORM public.create_notification(
      v_engineer_id,
      'mr_issued',
      'Materials Issued',
      FORMAT('MR %s has been issued. Slip: %s', v_mr_number, NEW.slip_number),
      'issue_slip',
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER issue_slip_issued_notify
  AFTER UPDATE ON public.issue_slips
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_mr_issued();
```

---

## Trigger: Low Stock → Notify Store/Admin

```sql
-- Called from apply_stock_transaction() trigger when stock drops below min_level

CREATE OR REPLACE FUNCTION public.notify_low_stock(
  p_material_id bigint,
  p_warehouse_id bigint,
  p_current_qty numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_min_level   numeric;
  v_mat_name    text;
  v_already_notified boolean;
BEGIN
  SELECT m.min_stock_level, m.name
  INTO v_min_level, v_mat_name
  FROM public.materials m
  WHERE m.id = p_material_id;

  IF p_current_qty <= v_min_level THEN
    -- Avoid duplicate notifications (check if one was sent in last 24h)
    SELECT EXISTS(
      SELECT 1 FROM public.notifications
      WHERE entity_type = 'material'
        AND entity_id = p_material_id
        AND type = 'low_stock'
        AND created_at > now() - INTERVAL '24 hours'
    ) INTO v_already_notified;

    IF NOT v_already_notified THEN
      PERFORM public.create_notification(
        u.user_id,
        'low_stock',
        'Low Stock Alert',
        FORMAT('%s is below minimum stock level (current: %s)', v_mat_name, p_current_qty),
        'material',
        p_material_id
      )
      FROM (
        SELECT user_id FROM public.get_users_by_role('admin')
        UNION ALL
        SELECT user_id FROM public.get_users_by_role('store')
      ) u;
    END IF;
  END IF;
END;
$$;
```

---

## Trigger: PR/PO Submitted → Notify Owner/Admin

```sql
-- Reuse same pattern as MR — notify admins/owners when PR or PO needs approval

CREATE OR REPLACE FUNCTION public.notify_pr_submitted()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.status = 'submitted' AND OLD.status = 'draft' THEN
    PERFORM public.create_notification(
      u.user_id,
      'approval_required',
      'Approval Required: Purchase Requisition',
      FORMAT('PR %s (₹%s) requires your approval.',
             NEW.pr_number,
             to_char(NEW.total_estimated_value, 'FM99,99,99,990.00')),
      'purchase_requisition',
      NEW.id
    )
    FROM (
      SELECT user_id FROM public.get_users_by_role('admin')
      UNION ALL
      SELECT user_id FROM public.get_users_by_role('owner')
    ) u;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER pr_submitted_notify
  AFTER UPDATE ON public.purchase_requisitions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_pr_submitted();
```

---

## Flutter: Mark Notification as Read

```dart
// In NotificationRepository
Future<void> markAsRead(int notificationId) async {
  await _client
      .from('notifications')
      .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
      .eq('id', notificationId);
}

Future<void> markAllAsRead() async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return;
  await _client
      .from('notifications')
      .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
      .eq('user_id', userId)
      .eq('is_read', false);
}
```

---

## Deep-Link Routing on Notification Tap

See `REALTIME_SUBSCRIPTIONS.md` → **Notification Types & Deep-Link Routes** table.

When a notification is tapped in the Flutter app:
```dart
void onNotificationTap(NotificationModel notification) {
  switch (notification.entityType) {
    case 'material_request':
      context.push('/material-requests/${notification.entityId}');
    case 'purchase_requisition':
      context.push('/procurement/pr/${notification.entityId}');
    case 'purchase_order':
      context.push('/procurement/po/${notification.entityId}');
    case 'issue_slip':
      context.push('/inventory/issuances/${notification.entityId}');
    case 'material':
      context.push('/inventory/stock/${notification.entityId}');
    default:
      context.push('/notifications');
  }
}
```
