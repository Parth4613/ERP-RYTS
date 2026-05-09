# Store Issuance and Purchase Request (PR) Update Fixes

## Audit Summary

### Current Implementation Status

**Good News**: The current issuance flow already implements the correct workflow:

1. **No Stock Case**:
   - Shows dialog: "Stock Unavailable"
   - Options: "Create Purchase Request" or "Cancel"
   - Does NOT auto-create PR silently ✓

2. **Partial Stock Case**:
   - Shows dialog: "Insufficient Stock"
   - Displays: Requested, Available, Shortage quantities
   - Options: "Issue Available Only", "Issue & Create PR", "Cancel"
   - User has full control ✓

3. **Full Stock Case**:
   - Shows confirmation dialog with after-issuance calculation
   - User must confirm before issuance ✓

### Issues Identified and Fixed

## 1. PR Update Button Not Working (Critical)

**Root Cause**: Missing RLS policies for UPDATE and DELETE operations on `purchase_request_items` and `purchase_requests` tables.

**Fix Applied**:
- Created `supabase_pr_update_fixes.sql` with proper RLS policies
- Added UPDATE and DELETE policies for `purchase_request_items`
- Added UPDATE and DELETE policies for `purchase_requests`
- Policies restrict updates to only draft/pending status
- Policies restrict to admin and store roles

**File**: `supabase_pr_update_fixes.sql`

**Action Required**: Apply this SQL file to your Supabase database

```sql
-- Apply to Supabase SQL Editor or via migration
```

## 2. PR Update Error Messaging (Fixed)

**Issue**: No feedback shown when PR update succeeds or fails

**Fix Applied**:
- Added success SnackBar when PR item quantity is updated
- Added error SnackBar with actual backend error message
- Error messages now display for 4 seconds for visibility

**File**: `lib/features/store/screens/store_procurement_screen.dart`

## 3. Stock Shortage Display (Fixed)

**Issue**: No visual indication of shortage quantities

**Fix Applied**:
- Added shortage calculation to IssuanceItemCard
- Added "Shortage" chip that displays shortage quantity in red
- Chip only shows when shortage > 0

**File**: `lib/features/store/widgets/issuance_item_card.dart`

## 4. Issue Button Disable Logic (Improved)

**Issue**: Issue button was disabled when stock = 0, but messaging was unclear

**Fix Applied**:
- Improved error message display
- Shows "Out of Stock" when stockAvailable == 0
- Shows "Cannot Issue" for other cases
- Added helpful text: "Stock is unavailable. Create a Purchase Request."
- "Create PR" button only shows when stock = 0

**File**: `lib/features/store/widgets/issuance_item_card.dart`

## Files Modified

1. **supabase_pr_update_fixes.sql** (NEW)
   - RLS policy fixes for PR updates
   - UPDATE and DELETE policies for purchase_request_items
   - UPDATE and DELETE policies for purchase_requests

2. **lib/features/store/screens/store_procurement_screen.dart**
   - Added success/error messaging for PR updates
   - Improved error feedback with actual backend errors

3. **lib/features/store/widgets/issuance_item_card.dart**
   - Added shortage calculation and display
   - Improved error messaging for out-of-stock cases
   - Better UI for disabled issue button state

4. **lib/features/store/widgets/issuance_dialog.dart** (NEW)
   - Created alternative dialog implementation (not currently used)
   - Can be used for future improvements

## Backend RPC Functions

The following RPC functions exist and are working correctly:

1. **update_pr_item** - Updates PR item quantity and remarks
   - Validates PR status (draft/pending only)
   - Updates purchase_request_items table
   - Updates purchase_requests updated_at timestamp

2. **remove_pr_item** - Removes item from PR
   - Validates PR status (draft/pending only)
   - Deletes item from purchase_request_items
   - Auto-deletes PR if no items remain

3. **update_pr_notes** - Updates PR notes
   - Validates PR status (draft/pending only)
   - Updates notes and timestamp

4. **delete_purchase_request** - Deletes entire PR
   - Validates PR status (draft/pending only)
   - Saves audit trail before deletion

## RLS Policy Details

### purchase_request_items

**Before**: Only SELECT and INSERT policies

**After**: Added UPDATE and DELETE policies
- UPDATE: Only allowed for draft/pending PRs by admin/store
- DELETE: Only allowed for draft/pending PRs by admin/store

### purchase_requests

**Before**: No UPDATE/DELETE policies

**After**: Added UPDATE and DELETE policies
- UPDATE: Only allowed for draft/pending status by admin/store
- DELETE: Only allowed for draft/pending status by admin/store

## Implementation Steps

### Step 1: Apply RLS Policy Fixes (REQUIRED)

Run the SQL file in Supabase SQL Editor:

```sql
-- Open supabase_pr_update_fixes.sql
-- Copy contents to Supabase SQL Editor
-- Execute the SQL
```

This is critical for the PR update button to work.

### Step 2: Test PR Update Functionality

1. Open Store Procurement screen
2. Navigate to "Purchase Requests" tab
3. Find a draft or pending PR
4. Click "Edit quantity" on an item
5. Change quantity and click "Update"
6. Verify:
   - Success message appears
   - Quantity is updated in the UI
   - Error message appears if update fails (with actual error)

### Step 3: Test Issuance Workflow

1. Open Store Dashboard
2. Navigate to a Material Request
3. Test each scenario:

**Scenario A: Full Stock**
- Verify confirmation dialog shows
- Verify after-issuance calculation is correct
- Issue material and verify success

**Scenario B: Partial Stock**
- Verify dialog shows shortage calculation
- Test "Issue Available Only" option
- Test "Issue & Create PR" option
- Verify PR is created only when user confirms

**Scenario C: No Stock**
- Verify dialog shows "Stock Unavailable"
- Verify "Create Purchase Request" button appears
- Verify manual PR creation works
- Verify NO auto-PR creation occurs

### Step 4: Verify Shortage Display

1. Open a Material Request with shortage items
2. Verify red "Shortage" chip appears
3. Verify shortage quantity is correct
4. Verify chip only shows when shortage > 0

## Verification Checklist

- [ ] Apply supabase_pr_update_fixes.sql to database
- [ ] PR update button works for draft PRs
- [ ] PR update button works for pending PRs
- [ ] PR update button shows success message
- [ ] PR update button shows error message on failure
- [ ] PR update is blocked for approved/ordered PRs
- [ ] Issuance with full stock works correctly
- [ ] Issuance with partial stock shows proper dialog
- [ ] Issuance with no stock shows PR creation option
- [ ] No auto-PR creation occurs
- [ ] Shortage chip displays correctly
- [ ] Issue button disabled when stock = 0
- [ ] Error messages are clear and actionable

## Known Limitations

1. **RLS Policy Application**: The SQL file must be manually applied to the database. This is not automated.

2. **RPC Function Security**: RPC functions use SECURITY DEFINER which bypasses RLS. This is intentional for proper functionality, but ensure the functions have proper status validation.

3. **Error Handling**: Some errors might still be generic. The actual Supabase error messages should provide more details for debugging.

## Future Improvements

1. **Add Remarks Field**: Allow users to add remarks when updating PR item quantities
2. **Inline Editing**: Implement inline editing for PR item remarks
3. **Bulk Actions**: Allow bulk quantity updates for multiple items
4. **Audit Trail**: Implement comprehensive audit logging for all PR changes
5. **Real-time Updates**: Add real-time subscriptions for PR updates across users

## Conclusion

The Store Department module's issuance and PR update workflows have been audited and fixed. The main issue was missing RLS policies preventing PR updates. The current implementation already follows the correct workflow for issuance with proper user confirmation dialogs. All identified issues have been addressed.

**Critical Action Required**: Apply `supabase_pr_update_fixes.sql` to your Supabase database to enable PR update functionality.
