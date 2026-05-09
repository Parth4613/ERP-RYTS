# Store Department Module Implementation

## Overview

This document describes the comprehensive Store Department module implemented for the construction project management system. The module enables store users to manage inventory, fulfill material requests, handle shortages, and maintain proper documentation through issuance receipts.

## Features Implemented

### 1. Inventory Management
- **View All Products**: Complete inventory listing with stock levels
- **Stock Tracking**: Real-time quantity, unit, and minimum stock level monitoring
- **Stock History**: Complete audit trail of inward and outward movements
- **Stock Status Indicators**: Color-coded status (In Stock, Low Stock, Out of Stock)
- **Search and Filter**: Quick search and filter by stock status

### 2. Material Request Handling
- **Pending Requests Dashboard**: View all incoming material requests
- **MR Detail View**: Detailed view of each material request
- **Stock Availability Check**: Real-time stock availability for each item
- **Issuance Status**: Can Issue, Partial, or No Stock indicators

### 3. Material Issuance
- **Full Issuance**: Issue complete requested quantity when stock is available
- **Partial Issuance**: Issue available quantity when stock is insufficient
- **Quantity Validation**: Automatic validation against available stock
- **Bulk Issuance**: Issue all items or available items at once
- **Real-time Updates**: Automatic inventory and MR status updates

### 4. Shortage Handling
- **Automatic Detection**: System detects shortages after issuance
- **Purchase Request Creation**: One-click PR creation for shortage items
- **MR Reference**: PRs are linked to original material requests
- **Shortage Dialog**: Easy interface to manage multiple shortages

### 5. Issuance Receipts (PDF Generation)
- **Professional Receipts**: PDF receipts for every issuance
- **Complete Information**: Project, engineer, product, quantity, date/time
- **Signature Placeholders**: Issued by and Received by sections
- **Download and Print**: Easy download and print functionality
- **Multiple Items**: Support for single and multiple item receipts

### 6. Status Tracking
- **Automatic Status Updates**: MR status updates automatically based on issuance
- **Status Progression**: Pending → Partially Issued → Fully Issued
- **Real-time Sync**: Status updates across all users
- **Status Indicators**: Visual badges for current status

### 7. Alerts System
- **Low Stock Alerts**: Items below minimum stock level
- **Out of Stock Alerts**: Items with zero stock
- **Frequent Shortages**: Items with recurring shortages
- **Dashboard Metrics**: Quick overview of all alerts

## Technical Architecture

### Database Schema Extensions

#### New Tables:
1. **issuance_logs**: Tracks all material issuances
2. **stock_history**: Complete audit trail of stock movements

#### New Views:
1. **store_dashboard_metrics**: Aggregated metrics for dashboard
2. **pending_mr_items_with_stock**: MR items with stock availability
3. **frequent_shortages**: Items with frequent shortages
4. **issuance_summary**: Issuance analytics by project and time

#### New Functions:
1. **issue_materials**: Automatic material issuance with inventory update
2. **get_mr_stock_availability**: Check stock availability for MR items
3. **update_mr_status**: Automatic MR status updates
4. **create_pr_from_shortage**: Create PR from shortage

### Flutter Architecture

#### Clean Architecture Layers:
- **Models**: Data models for store entities
- **Repository**: Data access layer with Supabase integration
- **Providers**: Riverpod state management
- **Widgets**: Reusable UI components
- **Screens**: Main store screens

#### Key Files:
```
lib/
├── core/
│   ├── models/store_models.dart
│   ├── repositories/store_repository.dart
│   └── services/pdf_service.dart
├── features/store/
│   ├── providers/store_providers.dart
│   ├── screens/
│   │   ├── store_dashboard.dart
│   │   ├── store_mr_detail_screen.dart
│   │   └── store_inventory_screen.dart
│   └── widgets/
│       ├── metrics_card.dart
│       ├── pending_requests_section.dart
│       ├── low_stock_alerts_section.dart
│       ├── frequent_shortages_section.dart
│       ├── issuance_item_card.dart
│       ├── shortage_dialog.dart
│       ├── pdf_receipt_dialog.dart
│       └── stock_history_dialog.dart
```

## Installation & Setup

### 1. Database Setup
Execute the SQL schema extensions:
```sql
-- Run the store schema
\i supabase_store_schema.sql

-- Run the store functions
\i supabase_store_functions.sql
```

### 2. Dependencies
Ensure these packages are in `pubspec.yaml`:
```yaml
dependencies:
  flutter_riverpod: ^3.3.1
  supabase_flutter: ^2.12.4
  intl: ^0.20.2
  pdf: ^3.10.7
  printing: ^5.11.1
  path_provider: ^2.1.2
```

### 3. Navigation Integration
The store dashboard is integrated into the main app navigation through the auth system.

## Usage Guide

### For Store Users

1. **Dashboard Overview**: Check pending MRs and stock alerts
2. **Process Material Requests**: 
   - View pending requests
   - Check stock availability
   - Issue materials (full or partial)
   - Generate PDF receipts
3. **Manage Inventory**:
   - View all products
   - Check stock levels
   - View stock history
   - Identify low stock items
4. **Handle Shortages**:
   - Detect shortages automatically
   - Create purchase requests
   - Track PR status

### Key Workflows

#### Material Issuance Workflow:
1. Store user views pending MRs on dashboard
2. Clicks on MR to view details
3. System shows stock availability for each item
4. Store user enters quantity to issue
5. System validates against available stock
6. Issuance is recorded and inventory updated
7. MR status automatically updated
8. PDF receipt generated
9. If shortage exists, prompted to create PR

#### Purchase Request Creation:
1. After partial issuance, shortage detected
2. System shows shortage dialog
3. Store user selects items to order
4. Enters quantity to order
5. PR created with MR reference
6. Procurement team notified

## Business Logic

### Issuance Logic:
```dart
// Check stock availability
if (currentStock >= requestedQuantity) {
  // Full issuance
  issueQuantity = requestedQuantity;
} else if (currentStock > 0) {
  // Partial issuance
  issueQuantity = currentStock;
  // Create shortage alert
} else {
  // No stock available
  // Prompt for PR creation
}
```

### Status Updates:
- **Pending**: No items issued yet
- **Partial**: Some items issued, some pending
- **Issued**: All items fully issued
- **Waiting for Procurement**: PR created, awaiting delivery

### Stock Movement Tracking:
- **Inward**: Stock added (purchase order, adjustment)
- **Outward**: Stock issued (issuance, adjustment)
- **Reference Type**: Issuance, PO, Adjustment, Initial
- **Automatic Logging**: All movements automatically logged

## PDF Generation

### Receipt Features:
- Professional layout with company branding
- Complete issuance details
- Project and engineer information
- Material details table
- Date and time stamps
- Signature placeholders
- Print-friendly format

### Receipt Content:
- Receipt ID
- Date and time of issuance
- Project name and engineer
- Product name and quantity
- Unit of measurement
- Issued by (store user)
- Received by (engineer)
- Notes if any

## Real-time Features

The module supports real-time updates for:
- Material request status changes
- Inventory quantity updates
- New material requests
- Purchase request creation
- Stock level changes

## Security Considerations

### Row Level Security (RLS):
- Store users can view and manage inventory
- Store users can issue materials
- Store users can create PRs
- Admin has full access

### Data Validation:
- Server-side validation for quantities
- Stock sufficiency checks
- Permission-based access control
- Audit trail for all operations

## Performance Optimizations

### Database Optimizations:
- Indexed views for fast queries
- Efficient joins and aggregations
- Materialized views for complex analytics
- Optimized triggers for automatic updates

### Flutter Optimizations:
- Lazy loading for large datasets
- Provider caching for performance
- Efficient state management
- Optimized PDF generation

## UI/UX Features

### Dashboard:
- Clean, modern interface
- Color-coded status indicators
- Quick action buttons
- Real-time metrics
- Alert summaries

### Material Request Handling:
- Intuitive item cards
- Stock availability indicators
- Quantity input validation
- Bulk action support
- Progress tracking

### Inventory Management:
- Search and filter functionality
- Stock status badges
- History tracking
- Quick actions
- Visual indicators

## Troubleshooting

### Common Issues:

1. **Issuance Not Working**:
   - Check stock availability
   - Verify user permissions
   - Check database connection

2. **PDF Not Generating**:
   - Verify PDF dependencies
   - Check device permissions
   - Ensure sufficient storage

3. **Status Not Updating**:
   - Check trigger functions
   - Verify RLS policies
   - Refresh providers

### Debug Tools:
- Flutter DevTools for performance
- Supabase Dashboard for database
- Riverpod DevTools for state
- Console logging for errors

## Future Enhancements

### Planned Features:
1. **Barcode Scanning**: Quick product identification
2. **Mobile App**: Native mobile store module
3. **Advanced Reporting**: Custom stock reports
4. **Notifications**: Push notifications for urgent requests
5. **Bulk Operations**: Bulk stock updates and issuances

### Scalability Improvements:
1. **Caching Layer**: Redis for frequently accessed data
2. **Microservices**: Separate store service
3. **Load Balancing**: For high-traffic scenarios
4. **Database Sharding**: For large inventories

## Integration Points

### With Other Modules:
- **Material Requests**: Integration with engineer MR creation
- **Purchase Requests**: Integration with procurement module
- **Cost Control**: Inventory value tracking
- **Projects**: Project-based material tracking

### API Endpoints:
- Material request endpoints
- Inventory management endpoints
- Issuance logging endpoints
- Stock history endpoints

## Support

For technical support or feature requests:
1. Check the documentation
2. Review the code comments
3. Create an issue with detailed information
4. Include error logs and reproduction steps

---

**Last Updated**: May 2026
**Version**: 1.0.0
**Framework**: Flutter + Supabase
