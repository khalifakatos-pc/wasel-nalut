/**
 * ============================================================================
 * KAPSO WHATSAPP CLOUD API SERVICE - WASEL NALUT
 * ============================================================================
 * Handles automated WhatsApp OTP delivery, 24-hour window management,
 * and phone verification across Customer, Captain, Merchant, and Admin apps.
 * ============================================================================
 */

const https = require('https');
const crypto = require('crypto');

class KapsoService {
  constructor() {
    this.enabled = process.env.KAPSO_ENABLED === 'true';
    this.apiKey = process.env.KAPSO_API_KEY || '';
    this.phoneNumberId = process.env.KAPSO_PHONE_NUMBER_ID || '1100582179808362';
    this.officialPhone = process.env.KAPSO_OFFICIAL_PHONE || '+218918207786';
    this.baseUrl = process.env.KAPSO_API_BASE_URL || 'https://api.kapso.ai/meta/whatsapp/v24.0';

    // In-memory OTP storage: phone -> { otp, expiresAt, role, attempts }
    this.otpStore = new Map();
  }

  /**
   * Normalizes any Libyan phone format to international digits without '+' for WhatsApp (e.g. 218918207786)
   */
  normalizePhone(phone) {
    if (!phone) return '';
    let digits = String(phone).trim().replace(/[^0-9]/g, '');
    if (digits.startsWith('0')) {
      digits = '218' + digits.substring(1);
    } else if (!digits.startsWith('218')) {
      digits = '218' + digits;
    }
    return digits;
  }

  /**
   * Generates a secure 4-digit OTP code
   */
  generateOtp() {
    return String(crypto.randomInt(1000, 10000));
  }

  /**
   * Constructs the role-specific WhatsApp OTP text
   */
  getOtpMessage(otp, role) {
    switch (role) {
      case 'captain':
      case 'driver':
        return `رمز التحقق الخاص بك كـ كابتن في أسطول واصل نالوت 🛵 هو:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. لا تشارك هذا الرمز مع أي شخص.`;
      case 'merchant':
      case 'store':
        return `رمز التحقق لإدارة المتجر في واصل نالوت 🏪 هو:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. لا تشاركه مع أي شخص.`;
      case 'admin':
        return `رمز التحقق الإداري لمنظومة واصل نالوت 🛡️ هو:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق.`;
      case 'customer':
      default:
        return `رمز التحقق لتطبيق واصل نالوت ⚡ هو:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. لا تشارك هذا الرمز حفاظاً على أمان حسابك.`;
    }
  }

  /**
   * Sends an HTTP request to Kapso WhatsApp Cloud API
   */
  async _postToKapso(endpoint, payload) {
    if (!this.apiKey) {
      return { statusCode: 401, data: { error: 'KAPSO_API_KEY not configured' } };
    }
    return new Promise((resolve, reject) => {
      const data = JSON.stringify(payload);
      const url = new URL(endpoint);

      const options = {
        hostname: url.hostname,
        port: url.port || 443,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.apiKey,
          'Content-Length': Buffer.byteLength(data),
        },
        timeout: 10000,
      };

      const req = https.request(options, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(body);
          } catch (e) {
            parsed = { raw: body };
          }
          resolve({ statusCode: res.statusCode, data: parsed });
        });
      });

      req.on('error', (err) => reject(err));
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Kapso API request timed out'));
      });

      req.write(data);
      req.end();
    });
  }

  /**
   * Requests and sends a WhatsApp OTP code via Kapso
   */
  async requestOtp(phone, role = 'customer') {
    if (!this.enabled) {
      return {
        success: false,
        disabled: true,
        mode: 'disabled',
        error: 'تم إيقاف خدمة واتساب كابسو مؤقتاً.',
      };
    }
    const normalized = this.normalizePhone(phone);
    if (!normalized || normalized.length < 10) {
      throw new Error('رقم الهاتف غير صالح. يرجى إدخال رقم ليبي صحيح.');
    }

    const otp = this.generateOtp();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

    // Store in memory
    this.otpStore.set(normalized, {
      otp,
      expiresAt,
      role,
      attempts: 0,
      createdAt: Date.now(),
    });

    const messageText = this.getOtpMessage(otp, role);
    const endpoint = `${this.baseUrl}/${this.phoneNumberId}/messages`;

    const payload = {
      messaging_product: 'whatsapp',
      to: normalized,
      type: 'text',
      text: {
        body: messageText,
      },
    };

    const cleanOfficialPhone = this.officialPhone.replace(/[^0-9]/g, '');
    const prefilledText = encodeURIComponent(`طلب تأكيد رقمي في واصل نالوت: ${normalized}\nالرمز المؤقت: ${otp}`);
    const deeplinkUrl = `https://wa.me/${cleanOfficialPhone}?text=${prefilledText}`;
    const nativeUri = `whatsapp://send?phone=${cleanOfficialPhone}&text=${prefilledText}`;

    try {
      const response = await this._postToKapso(endpoint, payload);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          success: true,
          mode: 'direct_delivery',
          normalizedPhone: normalized,
          messageId: response.data?.messages?.[0]?.id,
          expiresInSeconds: 300,
        };
      }

      // Meta 422 outside 24-hour window -> Try approved AUTHENTICATION template if configured
      if (response.statusCode === 422 && process.env.KAPSO_OTP_TEMPLATE_NAME) {
        const tplPayload = {
          messaging_product: 'whatsapp',
          to: normalized,
          type: 'template',
          template: {
            name: process.env.KAPSO_OTP_TEMPLATE_NAME,
            language: { code: process.env.KAPSO_OTP_TEMPLATE_LANG || 'ar' },
            components: [
              {
                type: 'body',
                parameters: [{ type: 'text', text: otp }]
              },
              {
                type: 'button',
                sub_type: 'otp',
                index: '0',
                parameters: [{ type: 'text', text: otp }]
              }
            ]
          }
        };
        const tplRes = await this._postToKapso(endpoint, tplPayload);
        if (tplRes.statusCode >= 200 && tplRes.statusCode < 300) {
          return {
            success: true,
            mode: 'direct_delivery',
            deliveryType: 'authentication_template',
            normalizedPhone: normalized,
            messageId: tplRes.data?.messages?.[0]?.id,
            expiresInSeconds: 300,
          };
        }
      }

      // Fallback when outside 24h window and template not yet approved
      if (response.statusCode === 422) {
        return {
          success: true,
          mode: 'deeplink_required',
          normalizedPhone: normalized,
          otp, // Returned to client so fallback verification works seamlessly
          officialPhone: this.officialPhone,
          deeplinkUrl,
          nativeUri,
          expiresInSeconds: 300,
          notice: 'يرجى فتح محادثة واتساب الرسمية لتلقي وتأكيد الرمز فوراً.',
        };
      }

      // Fallback for other Kapso errors
      console.warn(`Kapso non-200 response (${response.statusCode}):`, response.data);
      return {
        success: true,
        mode: 'deeplink_required',
        normalizedPhone: normalized,
        otp,
        officialPhone: this.officialPhone,
        deeplinkUrl,
        nativeUri,
        expiresInSeconds: 300,
      };
    } catch (err) {
      console.error('Kapso connection error, using fallback deeplink:', err.message);
      return {
        success: true,
        mode: 'deeplink_required',
        normalizedPhone: normalized,
        otp,
        officialPhone: this.officialPhone,
        deeplinkUrl,
        nativeUri,
        expiresInSeconds: 300,
      };
    }
  }

  /**
   * Verifies the submitted OTP against stored entry
   */
  verifyOtp(phone, enteredOtp) {
    const normalized = this.normalizePhone(phone);
    const stored = this.otpStore.get(normalized);

    if (!stored) {
      return {
        success: false,
        error: 'لم يتم طلب رمز تحقق لهذا الرقم أو انتهت صلاحيته.',
      };
    }

    if (Date.now() > stored.expiresAt) {
      this.otpStore.delete(normalized);
      return {
        success: false,
        error: 'انتهت صلاحية رمز التحقق (5 دقائق). يرجى طلب رمز جديد.',
      };
    }

    stored.attempts += 1;
    if (stored.attempts > 5) {
      this.otpStore.delete(normalized);
      return {
        success: false,
        error: 'تم تجاوز الحد الأقصى للمحاولات الخاطئة. يرجى طلب رمز جديد.',
      };
    }

    if (String(stored.otp).trim() !== String(enteredOtp).trim()) {
      return {
        success: false,
        error: 'رمز التحقق غير صحيح. تأكد من الرقم وأعد المحاولة.',
      };
    }

    // Success: Consume OTP
    const role = stored.role;
    this.otpStore.delete(normalized);

    return {
      success: true,
      verified: true,
      phone: normalized,
      role,
    };
  }

  /**
   * Sends a plain text message via Kapso WhatsApp Cloud API
   */
  async sendTextMessage(toPhone, messageText) {
    if (!this.enabled) return { success: false, disabled: true, error: 'Kapso WhatsApp is paused' };
    const normalized = this.normalizePhone(toPhone);
    if (!normalized) return { success: false, error: 'رقم هاتف غير صالح' };

    const endpoint = `${this.baseUrl}/${this.phoneNumberId}/messages`;
    const payload = {
      messaging_product: 'whatsapp',
      to: normalized,
      type: 'text',
      text: { body: messageText }
    };

    try {
      const response = await this._postToKapso(endpoint, payload);
      return {
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        data: response.data
      };
    } catch (err) {
      console.error(`[KapsoService] Error sending text message to ${normalized}:`, err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Sends an interactive button message (up to 3 buttons) via Kapso WhatsApp API
   */
  async sendInteractiveButtons(toPhone, bodyText, buttons = []) {
    if (!this.enabled) return { success: false, disabled: true, error: 'Kapso WhatsApp is paused' };
    const normalized = this.normalizePhone(toPhone);
    if (!normalized) return { success: false, error: 'رقم هاتف غير صالح' };

    const endpoint = `${this.baseUrl}/${this.phoneNumberId}/messages`;
    const formattedButtons = buttons.slice(0, 3).map((btn, idx) => ({
      type: 'reply',
      reply: {
        id: String(btn.id || `btn_${idx}`).substring(0, 256),
        title: String(btn.title || 'اختيار').substring(0, 20)
      }
    }));

    const payload = {
      messaging_product: 'whatsapp',
      to: normalized,
      type: 'interactive',
      interactive: {
        type: 'button',
        body: { text: bodyText },
        action: { buttons: formattedButtons }
      }
    };

    try {
      const response = await this._postToKapso(endpoint, payload);
      return {
        success: response.statusCode >= 200 && response.statusCode < 300,
        statusCode: response.statusCode,
        data: response.data
      };
    } catch (err) {
      console.error(`[KapsoService] Error sending interactive buttons to ${normalized}:`, err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Dispatches a new incoming order to a Merchant/Kitchen on WhatsApp with 15m/25m/reject buttons
   */
  async notifyMerchantNewOrder(order, store) {
    if (!store || !store.phone) return { success: false, error: 'المتجر لا يملك رقم هاتف مسجل' };

    const itemsSummary = (order.items || []).map(i => {
      const name = i.name || i.name_ar || i.title || 'وجبة';
      const qty = i.quantity || 1;
      const price = i.unit_price_lyd || i.price || 0;
      return `• ${name} (x${qty}) — ${price} د.ل`;
    }).join('\n');

    const bodyText = 
      `🔔 *طلب جديد وارد في واصل نالوت!*\n` +
      `رقم الطلب: *#${order.order_number || order.id}*\n` +
      `المتجر: *${store.name || store.name_ar || 'المطبخ'}*\n` +
      `العميل: ${order.customer_name || 'زبون واصل'}\n\n` +
      `📋 *الأصناف المطلوبة:*\n${itemsSummary}\n\n` +
      `💰 *المجموع*: *${order.total_amount_lyd || order.total || 0} د.ل*\n` +
      (order.notes ? `📝 *ملاحظات الزبون*: ${order.notes}\n\n` : '\n') +
      `يرجى اختيار وقت التجهيز لبدء التحضير وإشعار أقرب كابتن للاستلام:`;

    const buttons = [
      { id: `merchant_accept:${order.id}:15`, title: 'قبول (15 دقيقة) ⏱️' },
      { id: `merchant_accept:${order.id}:25`, title: 'قبول (25 دقيقة) ⏱️' },
      { id: `merchant_reject:${order.id}`, title: 'اعتذار / رفض ❌' }
    ];

    return await this.sendInteractiveButtons(store.phone, bodyText, buttons);
  }

  /**
   * Alerts the merchant/kitchen that the assigned captain has arrived at the store with OTP
   */
  async sendCaptainArrivalAlert(merchantPhone, order, captain) {
    if (!merchantPhone) return { success: false, error: 'رقم هاتف المتجر غير متوفر' };

    const handoverCode = order.handover_code || order.pickup_code || order.otp || '----';
    const captainName = captain?.full_name || captain?.name || 'كابتن واصل';
    const captainPhone = captain?.phone || '';

    const text = 
      `🛵 *إشعار وصول الكابتن إلى المطعم!*\n\n` +
      `وصل الكابتن *${captainName}* (${captainPhone}) لاستلام الطلب *#${order.order_number || order.id}*.\n\n` +
      `🔑 *رمز التسليم والتحقق (OTP)*: *${handoverCode}*\n\n` +
      `يرجى مطابقة الرمز وتسليم الطلب للكابتن لبدء رحلة التوصيل فوراً.`;

    return await this.sendTextMessage(merchantPhone, text);
  }

  /**
   * Sends an order status update directly to the customer on WhatsApp
   */
  async sendOrderStatusUpdate(customerPhone, order, statusText, extraInfo = '') {
    if (!customerPhone) return { success: false, error: 'رقم هاتف العميل غير متوفر' };

    const text = 
      `⚡ *واصل نالوت — تحديث طلبك #${order.order_number || order.id}*\n\n` +
      `الحالة: *${statusText}*\n` +
      (extraInfo ? `${extraInfo}\n\n` : '\n') +
      `شكراً لثقتكم بخدمة واصل نالوت!`;

    return await this.sendTextMessage(customerPhone, text);
  }

  /**
   * Translates internal order status keys into friendly Arabic phrases
   */
  getOrderStatusArabic(status) {
    const map = {
      'pending': 'بانتظار تأكيد المطعم ⏳',
      'order_placed': 'تم تسجيل الطلب وبانتظار المتجر ⏳',
      'accepted': 'تم قبول الطلب وجاري تجهيزه بالمطبخ 👨‍🍳',
      'preparing': 'قيد الطهي والتحضير بالمطبخ 🍳',
      'ready_for_pickup': 'الوجبة جاهزة وبانتظار استلام الكابتن 📦',
      'driver_assigned': 'تم تعيين كابتن للتوصيل وهو متوجه للمتجر 🛵',
      'driver_arrived': 'الكابتن وصل للمتجر لاستلام الوجبة 🏪',
      'picked_up': 'الكابتن استلم الوجبة وهو في الطريق إليك 🚀',
      'out_for_delivery': 'الكابتن في الطريق إلى موقعك في نالوت 📍',
      'delivered': 'تم تسليم الطلب بنجاح. بالهناء والشفاء! 🎉',
      'cancelled': 'تم إلغاء الطلب ❌'
    };
    return map[status] || status;
  }

  /**
   * Processes incoming WhatsApp webhooks (Interactive buttons, customer tracking, driver COD queries, location)
   */
  async processWebhookMessage(rawPayload, db = { orders: [], stores: [], drivers: [], users: [] }, io = null, hooks = {}) {
    if (!this.enabled) {
      return { success: true, ignored: true, reason: 'Kapso WhatsApp is paused' };
    }
    try {
      // 1. Extract message payload whether from Meta webhook, Kapso v2 format, or direct body
      let message = null;
      let contact = null;

      if (rawPayload?.entry?.[0]?.changes?.[0]?.value?.messages?.[0]) {
        const val = rawPayload.entry[0].changes[0].value;
        message = val.messages[0];
        contact = val.contacts?.[0];
      } else if (rawPayload?.message?.from) {
        message = rawPayload.message;
        contact = rawPayload.conversation || rawPayload.contact || null;
      } else if (rawPayload?.messages?.[0]) {
        message = rawPayload.messages[0];
        contact = rawPayload.contacts?.[0];
      } else if (rawPayload?.from) {
        message = rawPayload;
      }

      if (!message || !message.from) {
        return { success: false, ignored: true, reason: 'No actionable message found' };
      }

      const fromPhone = this.normalizePhone(message.from);
      const messageType = message.type || (message.interactive ? 'interactive' : (message.location ? 'location' : 'text'));
      const silentReplyToSender = Boolean(hooks?.silentReplyToSender);

      // 2. Identify actor from database
      const store = (db.stores || []).find(s => this.normalizePhone(s.phone) === fromPhone);
      const driver = (db.drivers || []).find(d => this.normalizePhone(d.phone) === fromPhone);
      const user = (db.users || []).find(u => this.normalizePhone(u.phone) === fromPhone);

      // ========================================================================
      // A. INTERACTIVE BUTTON / LIST REPLIES
      // ========================================================================
      if (messageType === 'interactive') {
        const buttonId = message.interactive?.button_reply?.id || message.interactive?.list_reply?.id;
        if (!buttonId) return { success: false, reason: 'Empty interactive reply' };

        // 1. Merchant Accepts Order (e.g. merchant_accept:ord_123:15)
        if (buttonId.startsWith('merchant_accept:')) {
          const [, orderId, prepTimeStr] = buttonId.split(':');
          const prepMinutes = parseInt(prepTimeStr || '15', 10);

          const order = (db.orders || []).find(o => o.id === orderId || o.order_number === orderId);
          if (!order) {
            if (!silentReplyToSender) {
              await this.sendTextMessage(fromPhone, `عذراً، لم يتم العثور على الطلب المراد قبوله (${orderId}).`);
            }
            return { success: false, error: 'Order not found' };
          }

          // Transition order to preparing
          order.status = 'preparing';
          order.prep_time_minutes = prepMinutes;
          order.estimated_prep_time_minutes = prepMinutes;
          order.accepted_at = order.accepted_at || new Date().toISOString();
          order.prep_started_at = order.prep_started_at || new Date().toISOString();
          order.updated_at = new Date().toISOString();

          if (hooks?.onOrderSave) {
            await hooks.onOrderSave(order);
          }

          // Real-time broadcasts
          if (io) {
            io.to(`store:${order.store_id}`).emit('order:status_changed', order);
            io.to(`user:${order.customer_id}`).emit('order:status_changed', order);
            io.to('admin:fleet').emit('order:status_changed', order);
            io.emit('kds:order_preparing', { order_id: order.id, prep_time: prepMinutes });
          }

          if (!silentReplyToSender) {
            await this.sendTextMessage(
              fromPhone,
              `✅ تم تأكيد قبول الطلب *#${order.order_number || order.id}* بنجاح!\n` +
              `⏱️ وقت التجهيز المحدد: *${prepMinutes} دقيقة*.\n` +
              `تم تحديث شاشة المطبخ KDS وتوجيه الكابتن للاستلام في الوقت المناسب.`
            );
          }

          // Notify customer if customer phone is available
          if (order.customer_phone) {
            await this.sendOrderStatusUpdate(
              order.customer_phone,
              order,
              `تم قبول طلبك من قِبل المطعم وهو قيد التحضير الآن 👨‍🍳`,
              `⏱️ وقت التجهيز المتوقع: ${prepMinutes} دقيقة.`
            );
          }

          return { success: true, action: 'order_accepted', order_id: order.id, prep_minutes: prepMinutes };
        }

        // 2. Merchant Rejects Order (e.g. merchant_reject:ord_123)
        if (buttonId.startsWith('merchant_reject:')) {
          const [, orderId] = buttonId.split(':');
          const order = (db.orders || []).find(o => o.id === orderId || o.order_number === orderId);
          if (!order) return { success: false, error: 'Order not found' };

          order.status = 'cancelled';
          order.cancellation_reason = 'merchant_rejected_via_whatsapp';
          order.cancelled_at = new Date().toISOString();
          order.updated_at = new Date().toISOString();

          if (hooks?.onOrderSave) {
            await hooks.onOrderSave(order);
          }

          if (io) {
            io.to(`store:${order.store_id}`).emit('order:status_changed', order);
            io.to(`user:${order.customer_id}`).emit('order:status_changed', order);
            io.to('admin:fleet').emit('order:status_changed', order);
          }

          if (!silentReplyToSender) {
            await this.sendTextMessage(
              fromPhone,
              `❌ تم تسجيل رفض الطلب *#${order.order_number || order.id}*. تم إشعار العميل وإدارة المنظومة.`
            );
          }

          if (order.customer_phone) {
            await this.sendOrderStatusUpdate(
              order.customer_phone,
              order,
              `نعتذر منك، لم يتمكن المطعم من قبول الطلب لعدم توفر الصنف حالياً ❌`
            );
          }

          return { success: true, action: 'order_rejected', order_id: order.id };
        }
      }

      // ========================================================================
      // B. GPS LOCATION SHARING
      // ========================================================================
      if (messageType === 'location') {
        const lat = message.location?.latitude;
        const lng = message.location?.longitude;

        if (lat && lng) {
          // Look for active order for this customer
          const activeOrder = (db.orders || []).find(o => 
            (this.normalizePhone(o.customer_phone) === fromPhone || o.customer_id === user?.id) &&
            !['delivered', 'cancelled'].includes(o.status)
          );

          if (activeOrder) {
            activeOrder.delivery_latitude = lat;
            activeOrder.delivery_lat = lat;
            activeOrder.delivery_longitude = lng;
            activeOrder.delivery_lng = lng;
            activeOrder.updated_at = new Date().toISOString();

            if (hooks?.onOrderSave) {
              await hooks.onOrderSave(activeOrder);
            }

            if (io) {
              io.to(`order:${activeOrder.id}`).emit('order:location_updated', {
                order_id: activeOrder.id,
                latitude: lat,
                longitude: lng
              });
              if (activeOrder.driver_id) {
                io.to(`driver:${activeOrder.driver_id}`).emit('driver:destination_updated', {
                  latitude: lat,
                  longitude: lng
                });
              }
            }

            if (!silentReplyToSender) {
              await this.sendTextMessage(
                fromPhone,
                `📍 تم استلام موقعك الجغرافي بنجاح!\nتم تحديث مسار الكابتن على الخريطة مباشرة لتسليم الطلب #${activeOrder.order_number || activeOrder.id} إلى مكان تواجدك بدقة في نالوت.`
              );
            }
            return { success: true, action: 'location_updated', order_id: activeOrder.id, lat, lng };
          } else {
            if (!silentReplyToSender) {
              await this.sendTextMessage(
                fromPhone,
                `📍 تم استلام إحداثيات موقعك الجغرافي بنجاح. يمكنك بدء طلب جديد وسنستخدم هذا الموقع لتوصيل وجبتك بدقة ⚡`
              );
            }
            return { success: true, action: 'location_received_no_active_order', lat, lng };
          }
        }
      }

      // ========================================================================
      // C. NATURAL LANGUAGE TEXT INQUIRIES & COMMANDS
      // ========================================================================
      if (messageType === 'text') {
        if (silentReplyToSender) {
          return { success: true, ignored: true, reason: 'Text conversation handled by Kapso AI Agent' };
        }

        const textBody = (message.text?.body || '').trim();
        const lower = textBody.toLowerCase();

        // 1. Order Status Inquiry ("وين طلبي", "حالة الطلب", "تتبع")
        if (lower.includes('وين طلبي') || lower.includes('حالة الطلب') || lower.includes('تتبع') || lower.includes('الطلب') || lower.includes('status')) {
          const activeOrder = (db.orders || []).find(o => 
            (this.normalizePhone(o.customer_phone) === fromPhone || o.customer_id === user?.id) &&
            !['delivered', 'cancelled'].includes(o.status)
          );

          if (activeOrder) {
            const orderStore = (db.stores || []).find(s => s.id === activeOrder.store_id);
            const orderDriver = activeOrder.driver_id ? (db.drivers || []).find(d => d.id === activeOrder.driver_id) : null;
            const statusArabic = this.getOrderStatusArabic(activeOrder.status);

            let reply = 
              `📦 *بيانات طلبك الحالي في واصل نالوت:*\n\n` +
              `• رقم الطلب: *#${activeOrder.order_number || activeOrder.id}*\n` +
              `• المتجر: *${orderStore?.name || orderStore?.name_ar || 'المطعم'}*\n` +
              `• الحالة الحالية: *${statusArabic}*\n` +
              `• إجمالي الفاتورة: *${activeOrder.total_amount_lyd || 0} د.ل*\n`;

            if (orderDriver) {
              reply += `• الكابتن المكلف: *${orderDriver.full_name || orderDriver.name || 'كابتن واصل'}* (📞 ${orderDriver.phone})\n`;
            }

            reply += `\nإذا أردت تحديث مكان التوصيل، يمكنك إرسال موقعك الجغرافي (Share Location) في هذه المحادثة فوراً 📍`;
            await this.sendTextMessage(fromPhone, reply);
            return { success: true, action: 'order_status_reported', order_id: activeOrder.id };
          } else {
            await this.sendTextMessage(
              fromPhone,
              `أهلاً بك في واصل نالوت ⚡\nلا يوجد لديك أي طلب نشط حالياً. يمكنك تصفح المطاعم وطلب وجبتك الآن عبر تطبيق واصل نالوت أو بإرسال كلمة *"المطاعم"* لمعرفة المتاح حالياً.`
            );
            return { success: true, action: 'no_active_order_reported' };
          }
        }

        // 2. Open Restaurants Inquiry ("المطاعم", "مطاعم", "مفتوح")
        if (lower.includes('المطاعم') || lower.includes('مطاعم') || lower.includes('مفتوح') || lower.includes('stores')) {
          const openStores = (db.stores || []).slice(0, 5);
          let listText = `🍴 *أبرز المطاعم المتاحة للتوصيل الآن في نالوت:*\n\n`;
          openStores.forEach((st, idx) => {
            const name = st.name || st.name_ar || 'مطعم';
            const rating = st.rating ? `⭐ ${st.rating}` : '';
            const deliveryTime = st.delivery_time_min ? `(⏱️ ${st.delivery_time_min}-${st.delivery_time_max || 30} دقيقة)` : '';
            listText += `${idx + 1}. *${name}* ${rating} ${deliveryTime}\n`;
          });
          listText += `\nللطلب، افتح تطبيق واصل نالوت واستمتع بأشهى الوجبات مع أسرع توصيل بالدينار الليبي ⚡`;

          await this.sendTextMessage(fromPhone, listText);
          return { success: true, action: 'stores_listed' };
        }

        // 3. Captain Escrow / COD Inquiry ("عهدة", "حسابي", "رصيد")
        if (lower.includes('عهدة') || lower.includes('حسابي') || lower.includes('رصيد') || lower.includes('escrow') || lower.includes('كاش')) {
          if (driver) {
            // Calculate active COD holdings for this driver
            const driverOrders = (db.orders || []).filter(o => o.driver_id === driver.id && o.status === 'delivered');
            const totalCashCollected = driverOrders.reduce((sum, o) => sum + (o.payment_method === 'cod' || !o.payment_method ? (o.total_amount_lyd || 0) : 0), 0);
            const settledAmount = driver.settled_cash_lyd || 0;
            const currentEscrow = driverOrders.length > 0
              ? Math.max(0, totalCashCollected - settledAmount)
              : Math.max(0, parseFloat(driver.cash_in_hand_lyd || 0));

            const reply = 
              `🛵 *كشف العهدة النقدية (COD) للكابتن ${driver.full_name || driver.name || 'كابتن واصل'}:*\n\n` +
              `• إجمالي الكاش المحصل بحوزتك: *${totalCashCollected.toFixed(2)} د.ل*\n` +
              `• إجمالي ما تم تسويته سابقاً: *${settledAmount.toFixed(2)} د.ل*\n` +
              `• رصيد العهدة المطلوب توريده للإدارة: *${currentEscrow.toFixed(2)} د.ل*\n\n` +
              `لتسوية العهدة النقدية مع الإدارة، يرجى مراجعة المشرف المالي أو مركز عمليات واصل نالوت.`;

            await this.sendTextMessage(fromPhone, reply);
            return { success: true, action: 'captain_escrow_reported', driver_id: driver.id };
          }
        }

        // 4. Merchant Item Availability ("أوقف صنف", "اوقف صنف", "نفد صنف")
        if (lower.includes('اوقف صنف') || lower.includes('أوقف صنف') || lower.includes('وقف صنف')) {
          if (store) {
            const query = textBody.replace(/اوقف صنف|أوقف صنف|وقف صنف/gi, '').trim();
            const product = (db.products || []).find(p => 
              p.store_id === store.id && 
              (p.name?.toLowerCase().includes(query.toLowerCase()) || p.name_ar?.toLowerCase().includes(query.toLowerCase()))
            );

            if (product) {
              product.in_stock = false;
              product.is_available = false;

              if (hooks?.onProductSave) {
                await hooks.onProductSave(product);
              }

              if (io) {
                io.emit('product:stock_changed', {
                  product_id: product.id,
                  store_id: store.id,
                  in_stock: false,
                  is_available: false
                });
                io.emit('store:menu_updated', { store_id: store.id });
              }

              await this.sendTextMessage(
                fromPhone,
                `✅ تم إيقاف الصنف *(${product.name || product.name_ar})* في قائمة مطعمك فورياً بنجاح.\nلن يظهر للزبائن حتى تقوم بإعادة تفعيله.`
              );
              return { success: true, action: 'product_disabled', product_id: product.id };
            } else {
              await this.sendTextMessage(
                fromPhone,
                `لم يتم العثور على صنف مطابق للاسم "${query}" في قائمة مطعمك. يرجى التأكد من اسم الصنف وإعادة المحاولة.`
              );
              return { success: false, reason: 'Product not found' };
            }
          }
        }

        if (hooks?.skipGeneralGreeting) {
          return { success: true, ignored: true, reason: 'General greeting handled by Kapso AI Agent' };
        }

        // 5. Default General Conversational Greeting
        const welcomeReply = 
          `مرحباً بك في *واصل نالوت* ⚡ خدمة التوصيل الذكية الأولى في جبل نفوسة!\n\n` +
          `كيف يمكنني مساعدتك اليوم؟\n` +
          `• اكتب *"وين طلبي"* لمتابعة طلبك الحالي.\n` +
          `• اكتب *"المطاعم"* لتصفح قائمة المطاعم المفتوحة.\n` +
          `• أرسل موقعك الجغرافي 📍 لتثبيت عنوان التوصيل مباشرة.`;

        await this.sendTextMessage(fromPhone, welcomeReply);
        return { success: true, action: 'general_welcome_sent' };
      }

      return { success: true, ignored: true };
    } catch (err) {
      console.error('[KapsoService] Webhook processing exception:', err);
      return { success: false, error: err.message };
    }
  }
}

module.exports = new KapsoService();
