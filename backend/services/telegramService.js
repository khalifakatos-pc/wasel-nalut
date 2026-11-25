/**
 * ============================================================================
 * TELEGRAM BOT API SERVICE - WASEL NALUT (@WaselNalutbot)
 * ============================================================================
 * Official, zero-cost Telegram authentication (Deep-Link + request_contact
 * cryptographic phone ownership proof + 4-digit OTP), interactive Merchant
 * KDS controls, Captain COD escrow queries, Customer order tracking/GPS,
 * and Operations Admin alerts.
 * ============================================================================
 */

const https = require('https');
const crypto = require('crypto');

class TelegramService {
  constructor() {
    this.botToken = process.env.TELEGRAM_BOT_TOKEN || '';
    this.botUsername = process.env.TELEGRAM_BOT_USERNAME || 'WaselNalutbot';
    this.webhookSecret = process.env.TELEGRAM_WEBHOOK_SECRET || 'wasel_nalut_tg_wh_sec_2026';
    this.adminChatId = process.env.TELEGRAM_ADMIN_CHAT_ID || '';
    this.enabled = process.env.TELEGRAM_ENABLED !== 'false';

    // phone (2189...) -> { phone, chat_id, telegram_user_id, username, first_name, role, updated_at }
    this.links = new Map();
    // chat_id string -> pending sessionId awaiting contact share
    this.pendingChatSessions = new Map();
    // phone (2189...) -> { otp, expiresAt, role, attempts, sessionId, verifiedViaBot }
    this.otpStore = new Map();
    // sessionId -> { id, normalizedPhone, role, otp, verifiedViaBot, consumed, chatId, telegramUserId, firstName, createdAt, expiresAt }
    this.authSessions = new Map();
  }

  /**
   * Hydrates persistent phone <-> chat_id links from PostgreSQL on server startup
   */
  hydrateLinks(rows = []) {
    for (const r of rows) {
      const norm = this.normalizePhone(r.phone);
      if (norm && r.chat_id) {
        this.links.set(norm, {
          phone: norm,
          chat_id: String(r.chat_id),
          telegram_user_id: r.telegram_user_id ? String(r.telegram_user_id) : null,
          username: r.username || null,
          first_name: r.first_name || null,
          role: r.role || 'customer',
          updated_at: r.updated_at || new Date().toISOString(),
        });
      }
    }
  }

  /**
   * Normalizes any Libyan phone format to international digits without '+' (e.g. 218918207786)
   */
  normalizePhone(phone) {
    if (!phone) return '';
    const ascii = String(phone)
      .replace(/[٠-٩]/g, d => d.charCodeAt(0) - 1632)
      .replace(/[۰-۹]/g, d => d.charCodeAt(0) - 1776);
    let digits = ascii.trim().replace(/[^0-9]/g, '');
    if (digits.startsWith('00218')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '218' + digits.substring(1);
    } else if (!digits.startsWith('218') && digits.length >= 9) {
      digits = '218' + digits;
    }
    return digits;
  }

  generateOtp() {
    return String(crypto.randomInt(1000, 10000));
  }

  generateSessionId() {
    return 'tg_' + crypto.randomBytes(6).toString('hex');
  }

  getChatIdForPhone(phone) {
    const norm = this.normalizePhone(phone);
    if (!norm) return null;
    const entry = this.links.get(norm);
    return entry ? entry.chat_id : null;
  }

  /**
   * Calls Telegram Bot API (api.telegram.org/bot<token>/<method>)
   */
  async _callTelegramApi(method, payload = {}) {
    if (!this.enabled || !this.botToken) {
      return { ok: false, statusCode: 503, description: 'Telegram bot token not configured or disabled' };
    }

    return new Promise((resolve, reject) => {
      const data = JSON.stringify(payload);
      const options = {
        hostname: 'api.telegram.org',
        port: 443,
        path: `/bot${this.botToken}/${method}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
        timeout: 10000,
      };

      const req = https.request(options, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          try {
            const parsed = JSON.parse(body || '{}');
            resolve({ statusCode: res.statusCode, ...parsed });
          } catch (_) {
            resolve({ statusCode: res.statusCode, ok: false, raw: body });
          }
        });
      });

      req.on('error', (err) => reject(err));
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Telegram API request timed out'));
      });

      req.write(data);
      req.end();
    });
  }

  async sendTextMessage(chatId, text, extra = {}) {
    if (!chatId) return { ok: false, error: 'Missing chat_id' };
    try {
      return await this._callTelegramApi('sendMessage', {
        chat_id: chatId,
        text,
        parse_mode: 'Markdown',
        ...extra,
      });
    } catch (err) {
      console.error(`[TelegramService] sendTextMessage failed (${chatId}):`, err.message);
      return { ok: false, error: err.message };
    }
  }

  async sendAdminAlert(text) {
    if (!this.adminChatId) return { ok: false, skipped: true };
    return this.sendTextMessage(this.adminChatId, text);
  }

  getOtpMessage(otp, role) {
    switch (role) {
      case 'captain':
      case 'driver':
        return `🛵 *رمز التحقق الخاص بك كـ كابتن في أسطول واصل نالوت*:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. لا تشاركه مع أي شخص.`;
      case 'merchant':
      case 'store':
        return `🏪 *رمز التحقق لإدارة المتجر والمطبخ في واصل نالوت*:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. لا تشاركه مع أي شخص.`;
      case 'admin':
        return `🛡️ *رمز التحقق الإداري لواصل نالوت*:\n*${otp}*\n\nصالح لمدة 5 دقائق.`;
      case 'customer':
      default:
        return `⚡ *رمز التحقق لتطبيق واصل نالوت*:\n*${otp}*\n\nالرمز صالح لمدة 5 دقائق. أدخله في التطبيق لتسجيل الدخول.`;
    }
  }

  getOrderStatusArabic(status) {
    const map = {
      'pending': 'بانتظار تأكيد المطعم ⏳',
      'placed': 'تم استلام الطلب وبانتظار المطعم ⏳',
      'accepted': 'تم قبول الطلب وجاري التجهيز 👨‍🍳',
      'preparing': 'قيد التحضير بالمطبخ 🍳',
      'ready_for_pickup': 'الوجبة جاهزة وبانتظار الكابتن 📦',
      'driver_assigned': 'تم تعيين كابتن ومتوجه للمتجر 🛵',
      'driver_arrived': 'الكابتن وصل للمتجر لاستلام الطلب 🏪',
      'picked_up': 'الكابتن استلم الطلب وفي الطريق إليك 🚀',
      'out_for_delivery': 'الكابتن في الطريق إلى موقعك في نالوت 📍',
      'delivered': 'تم تسليم الطلب بنجاح. بالهناء والشفاء! 🎉',
      'cancelled': 'تم إلغاء الطلب ❌'
    };
    return map[status] || status;
  }

  /**
   * Requests Telegram OTP / One-Tap Deep-Link authentication
   * Security invariant: Never expose OTP in HTTP response before Telegram verifies contact.
   */
  async requestOtp(phone, role = 'customer') {
    if (!this.enabled) {
      return { success: false, disabled: true, error: 'خدمة تيليجرام متوقفة مؤقتاً.' };
    }

    const normalized = this.normalizePhone(phone);
    if (!normalized || normalized.length < 10) {
      throw new Error('رقم الهاتف غير صالح. يرجى إدخال رقم ليبي صحيح.');
    }

    const otp = this.generateOtp();
    const sessionId = this.generateSessionId();
    const expiresAt = Date.now() + 5 * 60 * 1000;
    const chatId = this.getChatIdForPhone(normalized);

    const session = {
      id: sessionId,
      normalizedPhone: normalized,
      role,
      otp,
      verifiedViaBot: Boolean(chatId),
      consumed: false,
      chatId: chatId || null,
      telegramUserId: null,
      firstName: null,
      createdAt: Date.now(),
      expiresAt,
    };

    this.authSessions.set(sessionId, session);
    this.otpStore.set(normalized, {
      otp,
      expiresAt,
      role,
      attempts: 0,
      sessionId,
      verifiedViaBot: Boolean(chatId),
    });

    const cleanBot = this.botUsername.replace(/^@/, '');
    const deeplinkUrl = `https://t.me/${cleanBot}?start=auth_${sessionId}`;
    const nativeUri = `tg://resolve?domain=${cleanBot}&start=auth_${sessionId}`;

    if (chatId) {
      try {
        const res = await this.sendTextMessage(chatId, this.getOtpMessage(otp, role));
        if (res && res.ok) {
          return {
            success: true,
            mode: 'direct_delivery',
            sessionId,
            normalizedPhone: normalized,
            botUsername: cleanBot,
            deeplinkUrl,
            nativeUri,
            expiresInSeconds: 300,
          };
        }
      } catch (err) {
        console.warn('[TelegramService] Direct OTP push error, falling back to deep-link:', err.message);
      }
    }

    return {
      success: true,
      mode: 'bot_verification_required',
      sessionId,
      normalizedPhone: normalized,
      botUsername: cleanBot,
      deeplinkUrl,
      nativeUri,
      expiresInSeconds: 300,
      notice: 'افتح بوت واصل في تيليجرام واضغط "بدء" ثم "مشاركة رقم هاتفي" لتأكيد الدخول فوراً.',
    };
  }

  /**
   * Checks whether a Telegram auth session was completed via bot contact sharing
   */
  getSessionStatus(sessionId) {
    const session = this.authSessions.get(String(sessionId || '').trim());
    if (!session) {
      return { exists: false, verified: false, expired: true };
    }
    if (Date.now() > session.expiresAt) {
      this.authSessions.delete(session.id);
      return { exists: false, verified: false, expired: true };
    }
    return {
      exists: true,
      verified: Boolean(session.verifiedViaBot && session.chatId && !session.consumed),
      consumed: Boolean(session.consumed),
      phone: session.normalizedPhone,
      role: session.role,
      firstName: session.firstName,
      chatId: session.chatId,
    };
  }

  consumeSession(sessionId) {
    const session = this.authSessions.get(String(sessionId || '').trim());
    if (!session || !session.verifiedViaBot || session.consumed || Date.now() > session.expiresAt) {
      return null;
    }
    session.consumed = true;
    this.otpStore.delete(session.normalizedPhone);
    return session;
  }

  /**
   * Verifies submitted 4-digit OTP (only valid once OTP was delivered/verified via Telegram)
   */
  verifyOtp(phone, enteredOtp) {
    const normalized = this.normalizePhone(phone);
    const stored = this.otpStore.get(normalized);

    if (!stored) {
      return { success: false, error: 'لم يتم طلب رمز تحقق لهذا الرقم أو انتهت صلاحيته.' };
    }
    if (Date.now() > stored.expiresAt) {
      this.otpStore.delete(normalized);
      return { success: false, error: 'انتهت صلاحية رمز التحقق (5 دقائق). أعد الطلب.' };
    }
    if (!stored.verifiedViaBot) {
      return { success: false, error: 'يرجى تأكيد رقمك أولاً عبر بوت تيليجرام لتلقي الرمز.' };
    }

    stored.attempts += 1;
    if (stored.attempts > 5) {
      this.otpStore.delete(normalized);
      return { success: false, error: 'تم تجاوز عدد المحاولات المسموح. اطلب رمزاً جديداً.' };
    }

    if (String(stored.otp).trim() !== String(enteredOtp).trim()) {
      return { success: false, error: 'رمز التحقق غير صحيح. تأكد من الرقم الذي وصلك في تيليجرام.' };
    }

    const session = stored.sessionId ? this.authSessions.get(stored.sessionId) : null;
    if (session) session.consumed = true;
    this.otpStore.delete(normalized);

    return {
      success: true,
      verified: true,
      phone: normalized,
      role: stored.role,
      firstName: session?.firstName || null,
      chatId: session?.chatId || this.getChatIdForPhone(normalized),
    };
  }

  /**
   * Sends new incoming order alert to linked Merchant / Kitchen with interactive inline buttons
   */
  async notifyMerchantNewOrder(order, store) {
    if (!this.enabled || !store || !store.phone) return { ok: false, skipped: true };
    const chatId = this.getChatIdForPhone(store.phone);
    if (!chatId) return { ok: false, skipped: true, reason: 'Store Telegram not linked' };

    const itemsSummary = (order.items || []).map(i => {
      const name = i.name_ar || i.name || i.title || 'وجبة';
      const qty = i.quantity || 1;
      const price = i.unit_price_lyd || i.price || 0;
      return `• ${name} (x${qty}) — ${price} د.ل`;
    }).join('\n');

    const text =
      `🔔 *طلب جديد وارد في واصل نالوت!*\n` +
      `رقم الطلب: *#${order.order_number || order.id}*\n` +
      `المتجر: *${store.name || 'المطبخ'}*\n` +
      `الزبون: ${order.customer_name || 'زبون واصل'}\n\n` +
      `📋 *الأصناف المطلوبة:*\n${itemsSummary}\n\n` +
      `💰 *الإجمالي*: *${order.total_amount_lyd || 0} د.ل*\n` +
      (order.notes ? `📝 *ملاحظات*: ${order.notes}\n\n` : '\n') +
      `اختر إجراء التحضير الآن:`;

    return this.sendTextMessage(chatId, text, {
      reply_markup: {
        inline_keyboard: [
          [
            { text: '⏱️ قبول (15د)', callback_data: `merchant_accept:${order.id}:15` },
            { text: '⏱️ قبول (25د)', callback_data: `merchant_accept:${order.id}:25` }
          ],
          [
            { text: '❌ اعتذار / رفض الطلب', callback_data: `merchant_reject:${order.id}` }
          ]
        ]
      }
    });
  }

  async sendCaptainArrivalAlert(merchantPhone, order, captain) {
    if (!this.enabled || !merchantPhone) return { ok: false, skipped: true };
    const chatId = this.getChatIdForPhone(merchantPhone);
    if (!chatId) return { ok: false, skipped: true };

    const handoverCode = order.handover_code || order.pickup_code || order.otp_code || '----';
    const captainName = captain?.full_name || captain?.name || 'كابتن واصل';
    const captainPhone = captain?.phone || '';

    const text =
      `🛵 *وصول الكابتن لاستلام الطلب!*\n\n` +
      `وصل الكابتن *${captainName}* (${captainPhone}) إلى المتجر للطلب *#${order.order_number || order.id}*.\n` +
      `🔑 *رمز التسليم (OTP)*: *${handoverCode}*`;

    return this.sendTextMessage(chatId, text);
  }

  async sendOrderStatusUpdate(customerPhone, order, statusText, extraInfo = '') {
    if (!this.enabled || !customerPhone) return { ok: false, skipped: true };
    const chatId = this.getChatIdForPhone(customerPhone);
    if (!chatId) return { ok: false, skipped: true };

    const text =
      `⚡ *تحديث طلبك #${order.order_number || order.id} في واصل نالوت*\n\n` +
      `الحالة: *${statusText}*\n` +
      (extraInfo ? `${extraInfo}\n\n` : '\n') +
      `شكراً لاستخدامك واصل نالوت 🇱🇾`;

    return this.sendTextMessage(chatId, text);
  }

  /**
   * Registers webhook on api.telegram.org
   */
  async setWebhook(webhookUrl) {
    if (!this.botToken) throw new Error('TELEGRAM_BOT_TOKEN is missing');
    return this._callTelegramApi('setWebhook', {
      url: webhookUrl,
      secret_token: this.webhookSecret,
      allowed_updates: ['message', 'callback_query'],
      drop_pending_updates: false,
    });
  }

  /**
   * Main Telegram Bot Webhook Update Processor
   */
  async processWebhookUpdate(update, db = { orders: [], stores: [], drivers: [], users: [] }, io = null, hooks = {}) {
    if (!this.enabled) {
      return { success: true, ignored: true, reason: 'Telegram is disabled' };
    }

    try {
      // ======================================================================
      // A. INLINE BUTTON CALLBACKS (Merchant Accept/Reject & Quick Menu)
      // ======================================================================
      if (update?.callback_query) {
        const cb = update.callback_query;
        const cbId = cb.id;
        const chatId = cb.message?.chat?.id ? String(cb.message.chat.id) : null;
        const messageId = cb.message?.message_id;
        const data = String(cb.data || '');

        await this._callTelegramApi('answerCallbackQuery', { callback_query_id: cbId }).catch(() => {});

        if (!chatId) return { success: false, reason: 'No chat_id in callback_query' };

        // Resolve linked phone for caller verification
        let callerPhone = null;
        for (const [p, link] of this.links.entries()) {
          if (String(link.chat_id) === chatId) {
            callerPhone = p;
            break;
          }
        }

        if (data.startsWith('merchant_accept:')) {
          const [, orderId, prepStr] = data.split(':');
          const prepMinutes = parseInt(prepStr || '15', 10);
          const order = (db.orders || []).find(o => o.id === orderId || String(o.order_number) === orderId);
          if (!order) {
            await this.sendTextMessage(chatId, `عذراً، لم يتم العثور على الطلب (${orderId}).`);
            return { success: false, error: 'Order not found' };
          }

          const orderStore = (db.stores || []).find(s => s.id === order.store_id);
          if (orderStore && callerPhone && this.normalizePhone(orderStore.phone) !== callerPhone) {
            await this.sendTextMessage(chatId, '⚠️ هذا الطلب يخص متجراً آخر.');
            return { success: false, error: 'Unauthorized merchant callback' };
          }

          order.status = 'preparing';
          order.prep_time_minutes = prepMinutes;
          order.accepted_at = order.accepted_at || new Date().toISOString();
          order.prep_started_at = order.prep_started_at || new Date().toISOString();
          order.updated_at = new Date().toISOString();

          if (hooks?.onOrderSave) await hooks.onOrderSave(order);
          if (io) {
            io.to(`store:${order.store_id}`).emit('order:status_changed', order);
            io.to(`user:${order.customer_id}`).emit('order:status_changed', order);
            io.to('admin:fleet').emit('order:status_changed', order);
            io.emit('kds:order_preparing', { order_id: order.id, prep_time: prepMinutes });
          }

          if (messageId) {
            await this._callTelegramApi('editMessageReplyMarkup', {
              chat_id: chatId,
              message_id: messageId,
              reply_markup: { inline_keyboard: [] }
            }).catch(() => {});
          }

          await this.sendTextMessage(
            chatId,
            `✅ تم قبول الطلب *#${order.order_number || order.id}* بنجاح (التجهيز: *${prepMinutes} دقيقة*) وتحديث شاشة المطبخ KDS.`
          );

          if (order.customer_phone) {
            await this.sendOrderStatusUpdate(
              order.customer_phone,
              order,
              'تم قبول طلبك من المطعم وهو قيد التحضير الآن 👨‍🍳',
              `⏱️ وقت التجهيز المتوقع: ${prepMinutes} دقيقة.`
            );
          }
          return { success: true, action: 'order_accepted', order_id: order.id, prep_minutes: prepMinutes };
        }

        if (data.startsWith('merchant_reject:')) {
          const [, orderId] = data.split(':');
          const order = (db.orders || []).find(o => o.id === orderId || String(o.order_number) === orderId);
          if (!order) return { success: false, error: 'Order not found' };

          const orderStore = (db.stores || []).find(s => s.id === order.store_id);
          if (orderStore && callerPhone && this.normalizePhone(orderStore.phone) !== callerPhone) {
            await this.sendTextMessage(chatId, '⚠️ هذا الطلب يخص متجراً آخر.');
            return { success: false, error: 'Unauthorized merchant callback' };
          }

          order.status = 'cancelled';
          order.cancellation_reason = 'merchant_rejected_via_telegram';
          order.cancelled_at = new Date().toISOString();
          order.updated_at = new Date().toISOString();

          if (hooks?.onOrderSave) await hooks.onOrderSave(order);
          if (io) {
            io.to(`store:${order.store_id}`).emit('order:status_changed', order);
            io.to(`user:${order.customer_id}`).emit('order:status_changed', order);
            io.to('admin:fleet').emit('order:status_changed', order);
          }

          if (messageId) {
            await this._callTelegramApi('editMessageReplyMarkup', {
              chat_id: chatId,
              message_id: messageId,
              reply_markup: { inline_keyboard: [] }
            }).catch(() => {});
          }

          await this.sendTextMessage(chatId, `❌ تم رفض الطلب *#${order.order_number || order.id}* وإشعار الزبون.`);
          if (order.customer_phone) {
            await this.sendOrderStatusUpdate(
              order.customer_phone,
              order,
              'نعتذر منك، لم يتمكن المطعم من تنفيذ الطلب حالياً ❌'
            );
          }
          return { success: true, action: 'order_rejected', order_id: order.id };
        }

        if (data === 'menu_stores') {
          return this._replyOpenStores(chatId, db);
        }
        if (data === 'menu_my_order') {
          return this._replyCustomerOrder(chatId, callerPhone, db);
        }
        if (data === 'menu_captain_escrow') {
          return this._replyCaptainEscrow(chatId, callerPhone, db);
        }
        return { success: true, action: 'callback_handled', data };
      }

      // ======================================================================
      // B. INCOMING MESSAGES
      // ======================================================================
      const msg = update?.message;
      if (!msg || !msg.chat?.id) {
        return { success: true, ignored: true, reason: 'No message object in update' };
      }

      const chatId = String(msg.chat.id);
      const fromUserId = String(msg.from?.id || '');
      const textBody = (msg.text || '').trim();

      // 1. CRYPTOGRAPHIC CONTACT SHARE (request_contact)
      if (msg.contact && msg.contact.phone_number) {
        if (msg.contact.user_id && String(msg.contact.user_id) !== fromUserId) {
          await this.sendTextMessage(
            chatId,
            '⚠️ لا يمكن قبول جهة اتصال شخص آخر. يرجى الضغط على زر *مشاركة رقم هاتفي* لتأكيد رقمك الشخصي.'
          );
          return { success: false, error: 'Contact ownership mismatch' };
        }

        const normPhone = this.normalizePhone(msg.contact.phone_number);
        const firstName = [msg.contact.first_name, msg.contact.last_name].filter(Boolean).join(' ').trim() || msg.from?.first_name || 'مستخدم واصل';
        const username = msg.from?.username || null;

        // Check if user opened bot via /start auth_<sessionId>
        const pendingSessionId = this.pendingChatSessions.get(chatId);
        if (pendingSessionId) {
          const session = this.authSessions.get(pendingSessionId);
          if (session && Date.now() <= session.expiresAt) {
            if (session.normalizedPhone !== normPhone) {
              await this.sendTextMessage(
                chatId,
                `⚠️ رقم هاتفك في تيليجرام (+${normPhone}) لا يطابق الرقم الذي أدخلته في التطبيق (+${session.normalizedPhone}).\nيرجى تعديل الرقم في التطبيق والمحاولة مجدداً.`
              );
              return { success: false, error: 'Phone mismatch with pending session' };
            }

            session.verifiedViaBot = true;
            session.chatId = chatId;
            session.telegramUserId = fromUserId;
            session.firstName = firstName;

            const otpEntry = this.otpStore.get(normPhone);
            if (otpEntry) otpEntry.verifiedViaBot = true;
          }
          this.pendingChatSessions.delete(chatId);
        }

        // Persist permanent phone <-> chat_id link
        const detectedRole = (db.stores || []).some(s => this.normalizePhone(s.phone) === normPhone)
          ? 'merchant'
          : ((db.drivers || []).some(d => this.normalizePhone(d.phone) === normPhone) ? 'captain' : 'customer');

        const linkRecord = {
          phone: normPhone,
          chat_id: chatId,
          telegram_user_id: fromUserId,
          username,
          first_name: firstName,
          role: detectedRole,
          updated_at: new Date().toISOString(),
        };
        this.links.set(normPhone, linkRecord);
        if (hooks?.onSaveLink) await hooks.onSaveLink(linkRecord);

        const activeOtp = this.otpStore.get(normPhone);
        let confirmText =
          `✅ *تم ربط وتوثيق رقمك (+${normPhone}) بنجاح!*\n` +
          `أهلاً بك *${firstName}* في منصة واصل نالوت ⚡\n\n`;

        if (activeOtp && activeOtp.verifiedViaBot) {
          confirmText +=
            `🔑 رمز الدخول المؤقت الخاص بك هو: *${activeOtp.otp}*\n` +
            `يمكنك العودة إلى تطبيق واصل الآن — سيتم تسجيل دخولك تلقائياً أو بإدخال الرمز.`;
        } else {
          confirmText += `ستصلك من هنا تنبيهات الطلبات الحية ورموز الدخول بأمان ومجاناً.`;
        }

        await this.sendTextMessage(chatId, confirmText, {
          reply_markup: { remove_keyboard: true }
        });
        return { success: true, action: 'contact_verified', phone: normPhone, role: detectedRole };
      }

      // Resolve linked phone if user already linked earlier
      let linkedPhone = null;
      for (const [p, link] of this.links.entries()) {
        if (String(link.chat_id) === chatId) {
          linkedPhone = p;
          break;
        }
      }

      // 2. /start COMMANDS (Auth Deep-Link, Captain Register, Support)
      if (textBody.startsWith('/start')) {
        const arg = textBody.replace(/^\/start\s*/, '').trim();

        if (arg.startsWith('auth_')) {
          const sessionId = arg.substring(5).trim();
          const session = this.authSessions.get(sessionId);

          if (!session || Date.now() > session.expiresAt) {
            await this.sendTextMessage(
              chatId,
              '⏳ انتهت صلاحية جلسة التحقق أو أن الرابط غير صالح.\nيرجى العودة للتطبيق والضغط على *"الدخول عبر تيليجرام"* من جديد.'
            );
            return { success: false, error: 'Auth session expired or invalid' };
          }

          this.pendingChatSessions.set(chatId, sessionId);

          // If this chatId is already linked to the EXACT same phone, auto-confirm immediately!
          if (linkedPhone && linkedPhone === session.normalizedPhone) {
            session.verifiedViaBot = true;
            session.chatId = chatId;
            session.telegramUserId = fromUserId;
            const otpEntry = this.otpStore.get(linkedPhone);
            if (otpEntry) otpEntry.verifiedViaBot = true;

            await this.sendTextMessage(
              chatId,
              `✅ *تم تأكيد دخولك لحسابك (+${linkedPhone})!*\n🔑 رمز التحقق: *${session.otp}*\nيمكنك الرجوع للتطبيق الآن وسيُفتح حسابك فوراً ⚡`
            );
            return { success: true, action: 'auth_auto_verified', sessionId };
          }

          await this.sendTextMessage(
            chatId,
            `🔐 *تأكيد الدخول إلى تطبيق واصل نالوت*\n\n` +
            `اضغط على الزر الأزرق بالأسفل لمشاركة رقم هاتفك (+${session.normalizedPhone}) وإتمام التحقق بأمان:`,
            {
              reply_markup: {
                keyboard: [
                  [{ text: '📱 مشاركة رقم هاتفي لتأكيد الحساب', request_contact: true }]
                ],
                one_time_keyboard: true,
                resize_keyboard: true
              }
            }
          );
          return { success: true, action: 'auth_contact_requested', sessionId };
        }

        if (arg === 'captain_register') {
          await this.sendTextMessage(
            chatId,
            `🛵 *طلب الانضمام لأسطول كباتن واصل نالوت*\n\n` +
            `مرحباً بك! للتسجيل ككابتن توصيل، أرسل رسالة واحدة تحتوي على:\n` +
            `1. الاسم الثلاثي\n` +
            `2. رقم الهاتف\n` +
            `3. نوع المركبة (سيارة / دراجة نارية) والمنطقة\n\n` +
            `أو اضغط *"مشاركة رقم هاتفي"* لنتواصل معك فورياً:` ,
            {
              reply_markup: {
                keyboard: [
                  [{ text: '📱 مشاركة رقم هاتفي للتواصل', request_contact: true }]
                ],
                one_time_keyboard: true,
                resize_keyboard: true
              }
            }
          );
          return { success: true, action: 'captain_register_prompted' };
        }

        // Standard /start menu
        await this.sendTextMessage(
          chatId,
          `أهلاً بك في *بوت واصل نالوت الرسمي* ⚡🇱🇾\n` +
          `بوابة التوصيل الذكية لمدينة نالوت وجبل نفوسة!\n\n` +
          `يمكنك ربط رقم هاتفك مرة واحدة بالأسفل لتفعيل إشعارات طلباتك والدخول السريع، أو اختيار إحدى الخدمات:`,
          {
            reply_markup: {
              inline_keyboard: [
                [
                  { text: '🍴 المطاعم المفتوحة', callback_data: 'menu_stores' },
                  { text: '📦 تتبع طلبي', callback_data: 'menu_my_order' }
                ],
                [
                  { text: '🛵 عهدة الكابتن المالية', callback_data: 'menu_captain_escrow' }
                ]
              ]
            }
          }
        );

        if (!linkedPhone) {
          await this.sendTextMessage(
            chatId,
            '👇 اضغط على الزر بالأسفل لربط رقمك بالحساب واستلام تنبيهات الطلبات:',
            {
              reply_markup: {
                keyboard: [
                  [{ text: '📱 ربط رقم هاتفي مع واصل نالوت', request_contact: true }]
                ],
                one_time_keyboard: true,
                resize_keyboard: true
              }
            }
          );
        }
        return { success: true, action: 'start_menu_sent' };
      }

      // 3. GPS LOCATION SHARE
      if (msg.location && msg.location.latitude && msg.location.longitude) {
        const lat = msg.location.latitude;
        const lng = msg.location.longitude;

        const activeOrder = linkedPhone
          ? (db.orders || []).find(o => this.normalizePhone(o.customer_phone) === linkedPhone && !['delivered', 'cancelled'].includes(o.status))
          : null;

        if (activeOrder) {
          activeOrder.delivery_latitude = lat;
          activeOrder.delivery_lat = lat;
          activeOrder.delivery_longitude = lng;
          activeOrder.delivery_lng = lng;
          activeOrder.updated_at = new Date().toISOString();
          if (hooks?.onOrderSave) await hooks.onOrderSave(activeOrder);

          if (io) {
            io.to(`order:${activeOrder.id}`).emit('order:location_updated', { order_id: activeOrder.id, latitude: lat, longitude: lng });
            if (activeOrder.driver_id) {
              io.to(`driver:${activeOrder.driver_id}`).emit('driver:destination_updated', { latitude: lat, longitude: lng });
            }
          }

          await this.sendTextMessage(
            chatId,
            `📍 تم تحديث موقع التوصيل للطلب *#${activeOrder.order_number || activeOrder.id}* بدقة على خريطة الكابتن!`
          );
          return { success: true, action: 'location_updated', order_id: activeOrder.id, lat, lng };
        }

        await this.sendTextMessage(
          chatId,
          `📍 تم استلام موقعك (${lat.toFixed(4)}, ${lng.toFixed(4)}). عند إرسال طلب عبر التطبيق، استخدم رابط التتبع أو حدّد العنوان من الخريطة.`
        );
        return { success: true, action: 'location_received' };
      }

      // 4. NATURAL LANGUAGE ARABIC QUERIES
      if (textBody) {
        const lower = textBody.toLowerCase();

        // Merchant stock toggle: "أوقف صنف بيتزا"
        if (lower.includes('اوقف صنف') || lower.includes('أوقف صنف') || lower.includes('وقف صنف')) {
          const store = linkedPhone ? (db.stores || []).find(s => this.normalizePhone(s.phone) === linkedPhone) : null;
          if (!store) {
            await this.sendTextMessage(chatId, '⚠️ هذه الميزة مخصصة لأصحاب المطاعم بعد ربط رقم المتجر بالبوت.');
            return { success: false, error: 'Store not linked' };
          }
          const query = textBody.replace(/اوقف صنف|أوقف صنف|وقف صنف/gi, '').trim();
          const product = (db.products || []).find(p =>
            p.store_id === store.id &&
            ((p.name || '').toLowerCase().includes(query.toLowerCase()) || (p.name_ar || '').toLowerCase().includes(query.toLowerCase()))
          );
          if (product) {
            product.in_stock = false;
            product.is_available = false;
            if (hooks?.onProductSave) await hooks.onProductSave(product);
            if (io) {
              io.emit('product:stock_changed', { product_id: product.id, store_id: store.id, in_stock: false, is_available: false });
              io.emit('store:menu_updated', { store_id: store.id });
            }
            await this.sendTextMessage(chatId, `✅ تم إيقاف الصنف *(${product.name_ar || product.name})* في قائمتك فوراً.`);
            return { success: true, action: 'product_disabled', product_id: product.id };
          }
          await this.sendTextMessage(chatId, `لم يُعثر على صنف يطابق "${query}" في قائمة متجرك.`);
          return { success: false, reason: 'Product not found' };
        }

        if (lower.includes('المطاعم') || lower.includes('مطاعم') || lower.includes('مفتوح')) {
          return this._replyOpenStores(chatId, db);
        }

        if (lower.includes('وين طلبي') || lower.includes('حالة الطلب') || lower.includes('طلبي') || lower.includes('تتبع')) {
          return this._replyCustomerOrder(chatId, linkedPhone, db);
        }

        if (lower.includes('عهدة') || lower.includes('حسابي') || lower.includes('رصيد')) {
          return this._replyCaptainEscrow(chatId, linkedPhone, db);
        }

        // Default help & forward message if it looks like a captain registration inquiry
        if (lower.includes('كابتن') || lower.includes('تسجيل') || lower.includes('انضمام')) {
          await this.sendAdminAlert(
            `📝 *طلب / استفسار تسجيل كابتن عبر تيليجرام*\n` +
            `المرسل: ${msg.from?.first_name || 'مستخدم'} (${msg.from?.username ? '@' + msg.from.username : 'Chat ' + chatId})\n` +
            `الهاتف المربوط: ${linkedPhone ? '+' + linkedPhone : 'غير مربوط'}\n` +
            `الرسالة:\n${textBody}`
          );
        }

        await this.sendTextMessage(
          chatId,
          `أهلاً بك في *واصل نالوت* ⚡\nاختر أمراً أو اكتب:\n• *"المطاعم"* لعرض المتاجر المفتوحة\n• *"وين طلبي"* لمتابعة طلبك\n• *"عهدة"* لكشف حساب الكابتن`,
          {
            reply_markup: {
              inline_keyboard: [
                [
                  { text: '🍴 المطاعم', callback_data: 'menu_stores' },
                  { text: '📦 وين طلبي؟', callback_data: 'menu_my_order' }
                ]
              ]
            }
          }
        );
        return { success: true, action: 'welcome_reply_sent' };
      }

      return { success: true, ignored: true };
    } catch (err) {
      console.error('[TelegramService] Webhook error:', err);
      return { success: false, error: err.message };
    }
  }

  async _replyOpenStores(chatId, db) {
    const stores = (db.stores || []).slice(0, 8);
    if (stores.length === 0) {
      await this.sendTextMessage(chatId, 'لا توجد متاجر متاحة حالياً.');
      return { success: true, action: 'stores_empty' };
    }
    let text = `🍴 *المطاعم والمتاجر المسجلة في واصل نالوت:*\n\n`;
    stores.forEach((st, idx) => {
      const stateIcon = st.is_open ? '🟢 مفتوح' : '⚪ مغلق';
      const fee = st.base_delivery_fee_lyd || 5;
      text += `${idx + 1}. *${st.name || st.name_ar}* — ${stateIcon} (⭐ ${st.rating || 4.8} • توصيل ${fee} د.ل)\n`;
    });
    await this.sendTextMessage(chatId, text);
    return { success: true, action: 'stores_listed' };
  }

  async _replyCustomerOrder(chatId, linkedPhone, db) {
    if (!linkedPhone) {
      await this.sendTextMessage(
        chatId,
        '⚠️ يرجى مشاركة رقم هاتفك أولاً بالضغط على /start ثم زر *"ربط رقم هاتفي"* لنتمكن من إظهار طلباتك.'
      );
      return { success: false, reason: 'Phone not linked' };
    }
    const activeOrder = (db.orders || []).find(o =>
      this.normalizePhone(o.customer_phone) === linkedPhone && !['delivered', 'cancelled'].includes(o.status)
    );
    if (!activeOrder) {
      await this.sendTextMessage(chatId, 'لا يوجد لديك طلب نشط حالياً. يمكنك الطلب عبر تطبيق واصل نالوت ⚡');
      return { success: true, action: 'no_active_order' };
    }
    const store = (db.stores || []).find(s => s.id === activeOrder.store_id);
    const driver = activeOrder.driver_id ? (db.drivers || []).find(d => d.id === activeOrder.driver_id) : null;
    let reply =
      `📦 *حالة طلبك #${activeOrder.order_number || activeOrder.id}:*\n` +
      `• المطعم: *${store?.name || activeOrder.store_name || 'المتجر'}*\n` +
      `• الحالة: *${this.getOrderStatusArabic(activeOrder.status)}*\n` +
      `• الإجمالي: *${activeOrder.total_amount_lyd || 0} د.ل*\n`;
    if (driver) {
      reply += `• الكابتن: *${driver.full_name || driver.name}* (📞 ${driver.phone})\n`;
    }
    reply += `\nيمكنك إرسال موقعك GPS مباشرة هنا لتحديث مكان التسليم 📍`;
    await this.sendTextMessage(chatId, reply);
    return { success: true, action: 'order_status_reported', order_id: activeOrder.id };
  }

  async _replyCaptainEscrow(chatId, linkedPhone, db) {
    if (!linkedPhone) {
      await this.sendTextMessage(chatId, '⚠️ يرجى ربط رقم هاتف الكابتن أولاً عبر /start.');
      return { success: false, reason: 'Phone not linked' };
    }
    const driver = (db.drivers || []).find(d => this.normalizePhone(d.phone) === linkedPhone);
    if (!driver) {
      await this.sendTextMessage(chatId, '⚠️ هذا الرقم غير مسجل ككابتن في أسطول واصل نالوت.');
      return { success: false, reason: 'Not a captain' };
    }
    const driverOrders = (db.orders || []).filter(o => o.driver_id === driver.id && o.status === 'delivered');
    const codCollected = driverOrders.reduce((s, o) => s + ((o.payment_method === 'cod' || o.payment_method === 'cash' || !o.payment_method) ? (o.total_amount_lyd || 0) : 0), 0);
    const settled = driver.settled_cash_lyd || 0;
    const due = driverOrders.length > 0 ? Math.max(0, codCollected - settled) : Math.max(0, parseFloat(driver.cash_in_hand_lyd || 0));

    const reply =
      `🛵 *كشف حساب الكابتن ${driver.full_name || driver.name}:*\n\n` +
      `• الكاش المستحق توريده (العهدة COD): *${due.toFixed(2)} د.ل*\n` +
      `• رصيد الأرباح بالمحفظة: *${Number(driver.wallet_balance_lyd || 0).toFixed(2)} د.ل*`;
    await this.sendTextMessage(chatId, reply);
    return { success: true, action: 'captain_escrow_reported', driver_id: driver.id };
  }
}

module.exports = new TelegramService();
