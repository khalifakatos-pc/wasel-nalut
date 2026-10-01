# Feature Specification: KDS Kitchen & Captain Delivery Handover Synchronization

**Feature Branch**: `004-kds-captain-handover-sync`  
**Created**: 2026-10-01  
**Status**: Ready for Implementation  
**Input**: "يبدو أن موضوع تطبيق الكابتن وتطبيق المطبخ فيه إشكالية بخصوص طلب بعد تجهيز الطلب؛ يأتي التسليم هناك مشكلة. قم باعداد تحليل باداة سبيكت"

---

## 🎯 1. Problem Statement & Root-Cause Diagnosis

في منظومة واصل نالوت، دورة حياة الطلب بين **المطبخ (تطبيق التاجر KDS)** و**كابتن التوصيل (تطبيق الكابتن)** تُمثل عنق الزجاجة للعملية التشغيلية. عند انتهاء تحضير الوجبة بالمطبخ وبدء إجراءات استلام الكابتن، تحدث عدة تعارضات تقنية تسببت في تعليق الطلب ومنع الكابتن من استلامه أو تسليمه:

### 🔴 الخلل الأول: شرط الفحص الصارم في تطبيق الكابتن (`isKitchenReady`)
- في ملف [`active_delivery_flow_screen.dart`](file:///c:/Users/kalifa/Desktop/wasel-app/flutter_driver_app/lib/active_delivery_flow_screen.dart) الأسطر `414` و `845`:
  ```dart
  final isKitchenReady = _orderBackendStatus == 'ready_for_pickup';
  ```
- **المشكلة**: إذا ضغط التاجر في المطبخ على زر `"تأكيد تسليم الوجبة للكابتن 🤝"` أولاً، يُرسل تطبيق التاجر للسيرفر حالة `out_for_delivery`.
- السيرفر يحدّث حالة الطلب إلى `out_for_delivery`.
- عندما يقوم تطبيق الكابتن بفحص حالة الطلب دورياً عبر `_fetchOrderStatus()`، تصبح `_orderBackendStatus = 'out_for_delivery'`.
- لأن `'out_for_delivery' != 'ready_for_pickup'`، يعتبر التطبيق أن المطبخ **لم ينتهِ بعد!**
- فيظهر للكابتن: *"⏳ الوجبة لا تزال قيد التحضير في المطبخ"* ويصبح زر الاستلام معطلاً بعنوان *"بانتظار تأكيد التجهيز من المطعم ⏳"*. وبالتالي يعلق الكابتن تماماً ولا يستطيع الانطلاق للزبون!

---

### 🔴 الخلل الثاني: رفض السيرفر لتكرار نقل العهدة (Lack of Idempotency)
- في خادم واصل [`backend/server.js`](file:///c:/Users/kalifa/Desktop/wasel-app/backend/server.js) السطر `2596`:
  ```javascript
  if (order.status !== 'ready_for_pickup') {
    return res.status(400).json({
      success: false,
      error: `لا يمكن تسليم الطلب وحالته الحالية هي: ${order.status}`
    });
  }
  ```
- **المشكلة**: إذا أقرّ المطعم بتسليم الوجبة للكابتن، أصبحت الحالة `out_for_delivery`.
- إذا ضغط الكابتن على زره لتأكيد الاستلام، يرفض السيرفر الطلب برمز **400 Bad Request** لأن الحالة ليست `ready_for_pickup` بل أصبحت بالفعل `out_for_delivery`!
- يُعرض للكابتن إشعار خطأ أحمر: *"تعذر استلام الطلب من المطعم: لا يمكن تسليم الطلب وحالته الحالية هي: out_for_delivery"*.

---

### 🔴 الخلل الثالث: غياب الانتقال التلقائي للخطوة التالية في تطبيق الكابتن (Auto-Stepper Advancement)
- عندما تتغير حالة الطلب على السيرفر إلى `out_for_delivery` أو `picked_up`، يكتفي تطبيق الكابتن بتحديث المتغير `_orderBackendStatus` فقط.
- لا يقوم التطبيق بنقل `currentStep` تلقائياً من `DeliveryStep.orderPickupChecklist` إلى `DeliveryStep.navigatingToCustomer`.
- يظل الكابتن محاصراً في شاشة قائمة فحص الاستلام للمطعم بينما الطلب أصبح قيد التوصيل فعلياً!

---

### 🔴 الخلل الرابع: التناقض في كود تسليم الوجبة (Handover Code vs Hardcoded '1234')
- في شاشة المطبخ [`kds_screen.dart`](file:///c:/Users/kalifa/Desktop/wasel-app/flutter_merchant_app/lib/kds_screen.dart)، يظهر صندوق كبير:
  > *"كود تسليم الوجبة للكابتن (OTP): 4821 - أعطِ هذا الكود للكابتن عند تسليم الطعام"*
- بينما في تطبيق الكابتن، كان يتم إرسال كود ثابت `'1234'` برمجياً دون حقل إدخال واضح، أو يحدث عدم تطابق إذا فعّل السيرفر التحقق الصارم من الكود.

---

### 🔴 الخلل الخامس: اختفاء الطلب المفاجئ من شاشة التاجر (KDS Disappearance)
- بمجرد ضغط التاجر على "تسليم الوجبة للكابتن"، ينتقل الطلب إلى تبويب "مكتملة"، ويختفي من تبويب "جاهز للاستلام"، مما يحرم التاجر من متابعة مكان الكابتن أو معرفة هل غادر المطعم فعلاً.

---

## 👥 2. User Scenarios & Prioritized User Stories

### User Story 1 - Flexible Bidirectional Handover (Priority: P1 - Critical)
**User Persona**: كابتن التوصيل وصاحب المطعم في نالوت.  
**Scenario**: عند استلام الكابتن للطلب من المطعم، سواءً ضغط المطعم على "تسليم الوجبة للكابتن" أولاً، أو ضغط الكابتن على "تأكيد الاستلام وبدء التوصيل"، يجب أن يتعرف النظام على أن الطلب أصبح قيد التوصيل (`out_for_delivery`) بسلاسة دون أقفال متقاطعة (No Deadlocks).

**Acceptance Scenarios**:
1. **Given** أن الطلب في حالة `ready_for_pickup` أو `out_for_delivery`،  
   **When** يضغط الكابتن على تأكيد الاستلام،  
   **Then** يقبل التطبيق والسيرفر العملية فوراً وينتقل الكابتن لمرحلة `navigatingToCustomer`.
2. **Given** أن المطعم ضغط على "تأكيد تسليم الوجبة للكابتن"،  
   **When** يستلم تطبيق الكابتن التحديث الدوري،  
   **Then** ينتقل التطبيق تلقائياً من شاشة فحص الاستلام إلى شاشة التوجه للزبون دون الحاجة لإعادة تشغيل التطبيق.
3. **Given** أن السيرفر استلم طلب `POST /api/v1/orders/:id/handover` لطلب حالته بالفعل `out_for_delivery`،  
   **When** ينفذ السيرفر الدالة،  
   **Then** يُرجع استجابة ناجحة (Idempotent 200 OK) بدلاً من خطأ 400.

---

### User Story 2 - Clear Handover Code & Mutual Confirmation (Priority: P1)
**User Persona**: كابتن التوصيل وأمين الصندوق بالمطعم.  
**Scenario**: يحتاج المطبخ للتأكد من هوية الكابتن قبل إعطائه الطعام، ويحتاج الكابتن لتأكيد استلام الطلب الصحيح.

**Acceptance Scenarios**:
1. **Given** شاشة الكابتن في مرحلة الاستلام،  
   **When** يطلب الكابتن تأكيد الاستلام،  
   **Then** يظهر له حقل إدخال رقمي مرن لكود التسليم (Handover Code) مع إمكانية التأكيد السريع بنقرة واحدة إذا كان الكابتن متواجداً داخل المطعم.
2. **Given** شاشة التاجر KDS،  
   **When** يتم تسليم الطلب،  
   **Then** يظل الطلب مرئياً في قسم "تم التسليم للكابتن / في الطريق للزبون" مع إمكانية الاتصال بالكابتن حتى وصوله للزبون.

---

### User Story 3 - Resilient State Recovery on App Lifecycle (Priority: P2)
**User Persona**: كابتن انقطع عنه الاتصال أو أغلقت شاشته أثناء التواجد في المطعم.  
**Scenario**: إذا أغلقت الشاشة أو تمت إعادة تشغيل التطبيق أثناء مرحلة الاستلام، يجب استعادة الحالة الحقيقية من السيرفر دون الرجوع لمرحلة التوجه للمطعم.

**Acceptance Scenarios**:
1. **Given** تطبيق الكابتن أعيد تشغيله والطلب في السيرفر حالته `out_for_delivery`،  
   **When** يفتح الكابتن التطبيق،  
   **Then** يفتح مباشرة على مرحلة `navigatingToCustomer` (التوجه للزبون) مع الخريطة المباشرة.

---

## 📋 3. Functional Requirements (FR)

- **FR-001**: تعديل فحص جاهزية المطبخ في `active_delivery_flow_screen.dart` ليشمل:
  ```dart
  final isKitchenReady = _orderBackendStatus == 'ready_for_pickup' || 
                         _orderBackendStatus == 'out_for_delivery' ||
                         _orderBackendStatus == 'picked_up';
  ```
- **FR-002**: إضافة مراقبة حية للانتقال التلقائي للخطوة التالية في `_fetchOrderStatus`: إذا تحولت الحالة إلى `out_for_delivery` وكان الكابتن لا يزال في `orderPickupChecklist`، يتم نقله تلقائياً إلى `navigatingToCustomer`.
- **FR-003**: جعل مسار السيرفر `POST /api/v1/orders/:id/handover` عملياً وغير تصادمي (Idempotent):
  - إذا كان الطلب في حالة `ready_for_pickup`: يتم تحويله إلى `out_for_delivery` وتحديث وقت التسليم.
  - إذا كان الطلب بالفعل في حالة `out_for_delivery`: يُرجع السيرفر نجاحاً (`200 OK`) مع `already_handed_over: true` دون إلقاء خطأ 400.
  - لا يُرفض إلا إذا كان الطلب `cancelled` أو لا يزال في مرحلة `placed` أو `preparing` المبكرة جداً.
- **FR-004**: جعل مسار السيرفر `POST /api/v1/orders/:id/status` متوافقاً مع نفس منطق التسليم الآمن.
- **FR-005**: في تطبيق التاجر `flutter_merchant_app`:
  - عند تأكيد التسليم للكابتن، يتم تحديث الحالة إلى `out_for_delivery` مع إرسال إشعار لحظي عبر السوكت لكابتن الطلب والزبون.
  - الاحتفاظ ببطاقة الطلب في شاشة KDS تحت قسم "في الطريق للزبون 🛵" بدلاً من إخفائها فوراً.
- **FR-006**: توحيد ومواءمة كود الاستلام (Handover Code):
  - السيرفر يقبل كود التسليم المطابق أو كود الطوارئ السريع `'1234'`.
  - تطبيق الكابتن يتيح تأكيد الاستلام المباشر أو إدخال الكود الظاهر على شاشة المطبخ.

---

## 🔄 4. Order State Machine Transition Matrix

| الحالة الحالية | الحدث / الإجراء | المنفّذ | الحالة الجديدة | النتيجة المقبولة |
| :--- | :--- | :--- | :--- | :--- |
| `placed` | بدء التحضير | التاجر | `preparing` | رادار الكباتن يرن، والمطبخ يشرع في الإعداد |
| `preparing` | وصول الكابتن للمطعم | الكابتن | `driver_arrived` | يظهر للتاجر أن الكابتن في المطعم، زر الكابتن ينتظر التجهيز |
| `driver_arrived` | تم التجهيز | التاجر | `ready_for_pickup` | تفعيل زر الاستلام فوراً لدى الكابتن |
| `ready_for_pickup` | تأكيد التسليم للكابتن | التاجر | `out_for_delivery` | نقل العهدة، انتقال الكابتن تلقائياً للتوصيل |
| `ready_for_pickup` | تأكيد الاستلام وانطلاق | الكابتن | `out_for_delivery` | نقل العهدة، انتقال الكابتن لموقع الزبون |
| `out_for_delivery` | محاولة تأكيد الاستلام مجدداً | الكابتن | `out_for_delivery` | **نجاح فوري (Idempotent 200 OK)** دون تعليق أو أخطاء |
| `out_for_delivery` | إدخال كود OTP الزبون | الكابتن | `delivered` | اكتمال الطلب وتحصيل الكاش وتسجيل العمولة |

---

## 🔒 5. Non-Functional Requirements (NFR)

- **NFR-001 (Zero Deadlocks)**: لا يجوز تحت أي ظرف من الظروف أن تؤدي سرعة أو أسبقية ضغط أحد الطرفين (التاجر أو الكابتن) إلى تجميد الآخر.
- **NFR-002 (Offline & Reconnect Resilience)**: إذا فقد الكابتن الاتصال بالمطعم ثم عاد، يتم استدعاء آخر حالة صحيحة والتقدم للخطوة المناسبة فوراً.
- **NFR-003 (Feedback Clarity)**: رسائل خطأ واضحة باللغة العربية بدلاً من رموز الاستثناء التقنية.
