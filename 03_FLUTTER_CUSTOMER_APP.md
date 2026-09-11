# 📱 Wasel Nalut: Customer Mobile & Web App Specifications
# Document: 03_FLUTTER_CUSTOMER_APP.md

This specification details the architecture, UI widgets, Libyan localization, and build procedures for the Customer Super-App (`flutter_mobile_app`).

---

## 1. Component Hierarchy & File Structure

```text
flutter_mobile_app/
├── lib/
│   ├── design_system.dart            # Unified colors, typography, elevations, radiuses
│   ├── home_screen.dart              # Multi-vertical Super-App home dashboard
│   ├── product_detail_sheet.dart     # Dual-mode food & e-commerce modifier bottom sheet
│   ├── order_tracking_screen.dart    # Live GPS tracking map & delivery timeline
│   └── main.dart                     # App harness with Dark/Light theme provider
├── pubspec.yaml
└── web/                              # Flutter Web assets & entrypoint
```

---

## 2. Product Detail & Modifier BottomSheet (`product_detail_sheet.dart`)

The modal sheet supports dual operating modes:

### 2.1 Food Mode (Wasel Eat & Mart)
- **Size Selection (Required Single Choice)**:
  - حجم عادي (سنجل): وجبة قياسية مع خبز طازج وبطاطا (`+0.00 د.ل`)
  - حجم مزدوج (دبل): شريحتان إضافيتان مع صلصة خاصة (`+5.00 د.ل`)
  - حجم عائلي كبير (جامبو): وجبة كاملة تكفي شخصين مع مشروب وبطاطا (`+12.00 د.ل`)
- **Add-on Customization (Multi-Choice)**:
  - صلصة ثومية ليبية حارة (`+1.50 د.ل`)
  - شريحة جبنة شيدر مدخنة (`+2.00 د.ل`)
  - بطاطا مقلية مقرمشة إضافية (`+3.50 د.ل`)
  - مخلل فلفل حار وزيتون نالوتي (`+1.00 د.ل`)
  - خبز تنور ليبي طازج (`+1.50 د.ل`)
- **Modern Radio Implementation (Anti-Deprecation)**:
  - Instead of `RadioListTile`, use custom `InkWell` + `AnimatedContainer` with circular check indicator to guarantee zero deprecation warnings on Flutter 3.24+ and 3.47+.
- **Kitchen Special Instructions**:
  - `TextField` with placeholder: `"مثال: بدون بصل، ثومية إضافية جانباً، تغليف ساخن..."`.

### 2.2 E-Commerce Mode (Wasel Marketplace / Mataa)
- Color swatch selector with check badges.
- Storage/variant chips: `128 GB`, `256 GB (+250 د.ل)`, `512 GB (+550 د.ل)`, `1 TB (+950 د.ل)`.
- Assurance perks: `"ضمان أصالة المنتج 100% معتمد"`, `"توصيل فوري نالوت"`.

### 2.3 Sticky Bottom Bar
- Stepper button (`- 1 +`).
- High-conversion CTA: `"إضافة للسلة • {totalPrice} د.ل"`.

---

## 3. Order Tracking Screen (`order_tracking_screen.dart`)

- **Interactive Vector Map**:
  - Uses `flutter_map` (or OpenStreetMap tiles).
  - Center: Nalut coordinates (`31.8687, 10.9818`).
  - Pulsing restaurant pickup pin and customer dropoff pin.
  - Animated driver marker updated via WebSocket GPS stream.
- **4-Stage Delivery Progress Line**:
  1. `تم تأكيد الطلب (Order Confirmed)`
  2. `المطعم يجهز الوجبة (Kitchen Preparing)`
  3. `الكابتن في الطريق إليك (On The Way)`
  4. `تم التوصيل بنجاح (Delivered)`
- **Delivery Confirmation OTP**:
  - Displays a high-contrast 4-digit code (e.g. `4821`).
  - Customer provides this code to the driver upon delivery to authenticate handoff.
- **Direct Captain Contact**:
  - One-tap phone dialer button (`tel:091xxxxxxx`).
  - One-tap chat/SMS button.

---

## 4. Web Compilation & Deployment Instructions

To deploy the Flutter Customer App as an interactive web app accessible at `https://wasel-nalut.onrender.com/app/`:

```powershell
# 1. Navigate to customer app
cd C:\Users\kalifa\super_app_delivery\flutter_mobile_app

# 2. Run static analysis (must report 0 issues)
flutter analyze

# 3. Build release web bundle with /app/ base-href
flutter build web --release --base-href /app/

# 4. Sync built files to backend static hosting folder
Copy-Item -Path "build\web\*" -Destination "..\backend\public\app\" -Recurse -Force
```
