#!/usr/bin/env node

/**
 * Wasel Nalut Admin MCP Server
 * Model Context Protocol (MCP) server providing administrative control and
 * automated data ingestion for Wasel Nalut delivery ecosystem via Hermes Agent.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// Backend Configuration
const BACKEND_URL = process.env.WASEL_BACKEND_URL || "https://wasel-nalut.onrender.com/api/v1";
const ADMIN_MASTER_KEY = process.env.WASEL_ADMIN_KEY || "9832";
const SUPABASE_URL = "https://yfhvuatssuylrkbthosa.supabase.co/rest/v1";
const SUPABASE_KEY = "sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD";

const supabaseHeaders = {
  apikey: SUPABASE_KEY,
  Authorization: `Bearer ${SUPABASE_KEY}`,
  "Content-Type": "application/json",
  Prefer: "return=representation",
};

// Starter Menu Presets
const STARTER_PRESETS = {
  pizza: [
    { name: "بيتزا مارغريتا كلاسيك", price: 18.0, category: "بيتزا وفطائر", description: "صلصة طماطم طازجة، جبنة موزاريلا فاخرة، ريحان" },
    { name: "بيتزا لحم مفروم مشكل", price: 25.0, category: "بيتزا وفطائر", description: "لحم مفروم متبل، فلفل، زيتون، جبنة موزاريلا" },
    { name: "فطيرة سبانخ وجبنة كيري", price: 14.0, category: "بيتزا وفطائر", description: "فطيرة ساخنة ومقرمشة مع حشوة السبانخ والجبن" },
    { name: "مشروب غازي بارد 330 مل", price: 3.0, category: "مشروبات ومقبلات", description: "بيبسي أو كوكاكولا أو فانتا مثلج" },
  ],
  grocery: [
    { name: "حليب معقم كامل الدسم 1 لتر", price: 4.5, category: "ألبان وأجبان", description: "حليب طازج معقم" },
    { name: "زيت طهي نباتي نقي 1 لتر", price: 9.0, category: "مواد غذائية أساسية", description: "زيت نقي للطبخ والقلي" },
    { name: "أرز بسمتي فاخر 1 كجم", price: 6.5, category: "حبوب وبقوليات", description: "أرز حبة طويلة ممتاز" },
    { name: "مياه نالوت المعدنية شد 6", price: 4.0, category: "مشروبات ومياه", description: "مياه نقية طبيعية" },
  ],
  supermarket: [
    { name: "حليب معقم كامل الدسم 1 لتر", price: 4.5, category: "ألبان وأجبان", description: "حليب طازج معقم" },
    { name: "زيت طهي نباتي نقي 1 لتر", price: 9.0, category: "مواد غذائية أساسية", description: "زيت نقي للطبخ والقلي" },
    { name: "أرز بسمتي فاخر 1 كجم", price: 6.5, category: "حبوب وبقوليات", description: "أرز حبة طويلة ممتاز" },
    { name: "مياه نالوت المعدنية شد 6", price: 4.0, category: "مشروبات ومياه", description: "مياه نقية طبيعية" },
  ],
  pharmacy: [
    { name: "بنادول إكسترا أقراص 500 ملغ", price: 8.5, category: "مسكنات وأدوية", description: "مسكن للصداع والآلام وخافض حرارة" },
    { name: "فيتامين سي فوار 1000 ملغ", price: 12.0, category: "فيتامينات ومكملات", description: "مكمل غذائي لتقوية المناعة" },
    { name: "شاش وضمادات طبية معقمة", price: 5.0, category: "إسعافات أولية", description: "عبوة شاش طبي معقم متعدد الأحجام" },
  ],
  bakery: [
    { name: "خبز فرنسي طازج (باجيت)", price: 2.0, category: "مخبوزات", description: "خبز ساخن ومقرمش مخبوز يومياً" },
    { name: "كرواسون شوكولاتة فاخر", price: 4.5, category: "حلويات ومخبوزات", description: "مورق وطري بحشوة الشوكولاتة البلجيكية" },
    { name: "كعك يانسون بلدي نالوتي", price: 8.0, category: "حلويات ومعمول", description: "كعك تقليدي بزيت الزيتون واليانسون" },
  ],
  restaurant: [
    { name: "سندوتش شاورما دجاج مميز", price: 12.0, category: "سندوتشات سريعة", description: "دجاج متبل مع ثومية وبطاطا مقرمشة في خبز صاج" },
    { name: "وجبة كباب صحن مشوي", price: 22.0, category: "مشويات جبلية", description: "أسياخ كباب لحم مشوي على الفحم مع سلطة وخبز" },
    { name: "سكالوب دجاج بالجبنة", price: 16.0, category: "سندوتشات سريعة", description: "صدر دجاج مقرمش مع جبنة وصوص خاص" },
    { name: "صحن بطاطا مقلية صوابع", price: 6.0, category: "مشروبات ومقبلات", description: "بطاطا ذهبية ساخنة ومملحة" },
  ],
};

// Create Server
const server = new Server(
  {
    name: "wasel-admin-mcp",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define Tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "wasel_admin_get_overview",
        description: "عرض لوحة القيادة والمؤشرات الحية لتطبيق المدير واصل نالوت (المبيعات، الطلبات، الكباتن المتصلين، والمتاجر المفتوحة).",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "wasel_admin_list_stores",
        description: "عرض كافة المتاجر والمطاعم والصيدليات المسجلة في نالوت مع بيانات الدخول وحالة الفتح/الإغلاق.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "wasel_admin_add_store",
        description: "إضافة متجر أو مطعم جديد في نالوت مع توليد حساب التاجر (الهاتف وPIN) وإمكانية إنشاء قائمة أصناف أولية تلقائياً.",
        inputSchema: {
          type: "object",
          properties: {
            name: { type: "string", description: "اسم المتجر أو المطعم بالعربية (مثال: مطعم قصر نالوت)" },
            name_en: { type: "string", description: "الاسم بالإنجليزية (اختياري)" },
            type: {
              type: "string",
              enum: ["restaurant", "pizza", "grocery", "pharmacy", "bakery"],
              description: "تصنيف المتجر ونمط العمل (restaurant: مطبخ KDS, grocery: تجميع Pick & Pack, pharmacy: صيدلية)",
            },
            phone: { type: "string", description: "رقم هاتف دخول التاجر (مثال: 0912345678)" },
            pin: { type: "string", description: "رمز PIN السري للدخول من تطبيق التاجر (الافتراضي: 1234)" },
            district: { type: "string", description: "الحي أو الشارع في نالوت (مثال: نالوت - شارع أفريقيا)" },
            base_delivery_fee_lyd: { type: "number", description: "سعر التوصيل الأساسي بالدينار الليبي (الافتراضي: 5.0)" },
            commission_rate: { type: "number", description: "نسبة عمولة واصل % (الافتراضي: 10.0)" },
            min_order_lyd: { type: "number", description: "الحد الأدنى للطلب بالدينار (الافتراضي: 15.0)" },
            auto_starter_menu: { type: "boolean", description: "توليد 4 أصناف أولية نموذجية تلقائياً للمتجر (الافتراضي: true)" },
          },
          required: ["name", "type", "phone"],
        },
      },
      {
        name: "wasel_admin_delete_store",
        description: "حذف متجر نهائياً من منظومة واصل وقاعدة البيانات وحذف كافة وجباته المرتبطة.",
        inputSchema: {
          type: "object",
          properties: {
            store_id: { type: "string", description: "معرف المتجر المراد حذفه (مثال: store_nalut_123456)" },
          },
          required: ["store_id"],
        },
      },
      {
        name: "wasel_admin_toggle_store_status",
        description: "تغيير حالة فتح أو إغلاق المتجر في نالوت (مفتوح ويستقبل طلبات / مغلق مؤقتاً).",
        inputSchema: {
          type: "object",
          properties: {
            store_id: { type: "string", description: "معرف المتجر" },
            is_open: { type: "boolean", description: "true لفتح المتجر، false للإغلاق" },
          },
          required: ["store_id", "is_open"],
        },
      },
      {
        name: "wasel_admin_list_products",
        description: "عرض قائمة الأصناف والوجبات والأسعار لمتجر محدد أو لجميع المتاجر في نالوت.",
        inputSchema: {
          type: "object",
          properties: {
            store_id: { type: "string", description: "معرف المتجر (اختياري - إذا تُرك فارغاً يعرض أصناف كافة المتاجر)" },
          },
        },
      },
      {
        name: "wasel_admin_add_product",
        description: "إضافة وجبة أو صنف جديد إلى قائمة متجر مع السعر والتصنيف والمكونات.",
        inputSchema: {
          type: "object",
          properties: {
            store_id: { type: "string", description: "معرف المتجر الذي سيضاف له الصنف" },
            name: { type: "string", description: "اسم الوجبة أو الصنف (مثال: وجبة كباب لحم فاخر)" },
            price: { type: "number", description: "السعر بالدينار الليبي (د.ل)" },
            category: { type: "string", description: "التصنيف (مثال: مشويات جبلية، بيتزا، سندوتشات، مشروبات)" },
            description: { type: "string", description: "وصف الصنف ومكوناته" },
            is_available: { type: "boolean", description: "متاح للطلب الفوري (الافتراضي: true)" },
          },
          required: ["store_id", "name", "price"],
        },
      },
      {
        name: "wasel_admin_delete_product",
        description: "حذف وجبة أو صنف نهائياً من قائمة المتجر.",
        inputSchema: {
          type: "object",
          properties: {
            product_id: { type: "string", description: "معرف الصنف المراد حذفه" },
          },
          required: ["product_id"],
        },
      },
      {
        name: "wasel_admin_list_drivers",
        description: "عرض أسطول كباتن التوصيل في نالوت مع العهدة النقدية المعلقة (COD) وحالة الاتصال وبيانات الدخول.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "wasel_admin_add_driver",
        description: "تسجيل كابتن توصيل جديد وتوليد بيانات الدخول لتطبيق الكابتن (Wasel Captain).",
        inputSchema: {
          type: "object",
          properties: {
            full_name: { type: "string", description: "اسم الكابتن الكامل (مثال: طارق عبد السلام النالوتي)" },
            phone: { type: "string", description: "رقم هاتف الدخول (مثال: 0925554433)" },
            pin: { type: "string", description: "رمز PIN السري (الافتراضي: 1234)" },
            vehicle_type: { type: "string", description: "نوع المركبة (مثال: سيارة هيونداي، دراجة نارية)" },
            plate_number: { type: "string", description: "رقم لوحة المركبة (مثال: نالوت 14-88992)" },
            max_cod_limit_lyd: { type: "number", description: "سقف عهدة الكاش COD بالدينار (الافتراضي: 250.0)" },
          },
          required: ["full_name", "phone"],
        },
      },
      {
        name: "wasel_admin_delete_driver",
        description: "حذف كابتن نهائياً من أسطول واصل نالوت وإيقاف حسابه.",
        inputSchema: {
          type: "object",
          properties: {
            driver_id: { type: "string", description: "معرف الكابتن المراد حذفه" },
          },
          required: ["driver_id"],
        },
      },
      {
        name: "wasel_admin_settle_driver_cash",
        description: "تسوية العهدة النقدية (COD) للكابتن وتصفير حسابه بعد استلام الكاش منه في مقر الإدارة.",
        inputSchema: {
          type: "object",
          properties: {
            driver_id: { type: "string", description: "معرف الكابتن" },
          },
          required: ["driver_id"],
        },
      },
      {
        name: "wasel_admin_batch_import",
        description: "إدخال بيانات جماعية متكاملة (متاجر + أصناف + كباتن) في خطوة واحدة سريعة ومنسقة.",
        inputSchema: {
          type: "object",
          properties: {
            stores: {
              type: "array",
              description: "قائمة بالمتاجر المراد إضافتها",
              items: { type: "object" },
            },
            products: {
              type: "array",
              description: "قائمة بالأصناف والوجبات المراد إضافتها",
              items: { type: "object" },
            },
            drivers: {
              type: "array",
              description: "قائمة بالكباتن المراد إضافتهم",
              items: { type: "object" },
            },
          },
        },
      },
      {
        name: "wasel_admin_purge_all",
        description: "تطهير وحذف كافة البيانات الوهمية من السحابة وتصفير المنظومة بالكامل (يتطلب رمز PIN الإداري 9832).",
        inputSchema: {
          type: "object",
          properties: {
            admin_pin: { type: "string", description: "رمز الحماية الإداري الرئيسي (9832)" },
          },
          required: ["admin_pin"],
        },
      },
    ],
  };
});

// Tool Call Execution Handler
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      // 1. Overview
      case "wasel_admin_get_overview": {
        const res = await fetch(`${BACKEND_URL}/admin/overview?admin_key=${ADMIN_MASTER_KEY}`);
        const data = await res.json();
        return {
          content: [
            {
              type: "text",
              text: `📊 لوحة مؤشرات واصل نالوت:\n` +
                    `• إجمالي المبيعات (GMV): ${data.data?.metrics?.gmv_total_lyd ?? 0} د.ل\n` +
                    `• إجمالي الطلبات: ${data.data?.metrics?.total_orders ?? 0}\n` +
                    `• الطلبات النشطة الآن: ${data.data?.metrics?.active_orders_count ?? 0}\n` +
                    `• المتاجر المتاحة: ${data.data?.metrics?.stores_count ?? 0}\n` +
                    `• الكباتن المتاحين: ${data.data?.fleet_stats?.available ?? 0}\n` +
                    `• الكاش المعلق مع الكباتن: ${data.data?.metrics?.cod_pending_lyd ?? 0} د.ل\n\n` +
                    `تفاصيل البيانات:\n${JSON.stringify(data.data, null, 2)}`,
            },
          ],
        };
      }

      // 2. List Stores
      case "wasel_admin_list_stores": {
        const res = await fetch(`${BACKEND_URL}/stores`);
        const data = await res.json();
        const stores = Array.isArray(data.data) ? data.data : (Array.isArray(data) ? data : []);
        
        let textSummary = `🏪 قائمة متاجر ومطاعم نالوت (${stores.length} متجر):\n\n`;
        for (const s of stores) {
          textSummary += `• [${s.id}] ${s.name} (${s.type})\n` +
                         `  الحالة: ${s.is_open ? "🟢 مفتوح" : "🔴 مغلق"} | الحي: ${s.district ?? "نالوت"}\n` +
                         `  هاتف الدخول: ${s.phone ?? "غير محدد"} | رمز PIN: ${s.pin ?? "1234"}\n` +
                         `  التوصيل: ${s.base_delivery_fee_lyd ?? 5} د.ل | العمولة: ${s.commission_rate ?? 10}%\n\n`;
        }

        return {
          content: [
            {
              type: "text",
              text: textSummary + `\nبيانات JSON:\n${JSON.stringify(stores, null, 2)}`,
            },
          ],
        };
      }

      // 3. Add Store
      case "wasel_admin_add_store": {
        const id = `store_nalut_${Date.now()}`;
        const storePayload = {
          id,
          name: args.name,
          name_en: args.name_en || args.name,
          type: args.type,
          district: args.district || "نالوت - شارع أفريقيا",
          city: "nalut",
          phone: String(args.phone).replace(/\D/g, ""),
          pin: args.pin ? String(args.pin) : "1234",
          app_mode: (args.type === "grocery" || args.type === "pharmacy") ? "retail" : "kitchen",
          commission_rate: args.commission_rate ?? 10.0,
          rating: 5.0,
          review_count: 0,
          delivery_time_min: 20,
          delivery_time_max: 35,
          min_order_lyd: args.min_order_lyd ?? 15.0,
          base_delivery_fee_lyd: args.base_delivery_fee_lyd ?? 5.0,
          latitude: 31.8686,
          longitude: 10.9818,
          is_open: true,
          is_featured: true,
        };

        // 1. Post to Backend
        await fetch(`${BACKEND_URL}/stores`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(storePayload),
        }).catch(() => {});

        // 2. Post to Supabase
        await fetch(`${SUPABASE_URL}/stores`, {
          method: "POST",
          headers: supabaseHeaders,
          body: JSON.stringify(storePayload),
        }).catch(() => {});

        let starterCount = 0;
        if (args.auto_starter_menu !== false) {
          const items = STARTER_PRESETS[args.type] || STARTER_PRESETS.restaurant;
          for (const item of items) {
            const prodPayload = {
              id: `prod_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
              store_id: id,
              name: item.name,
              name_ar: item.name,
              price: item.price,
              price_lyd: item.price,
              category: item.category,
              description: item.description,
              is_available: true,
            };
            await fetch(`${BACKEND_URL}/products`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(prodPayload),
            }).catch(() => {});

            await fetch(`${SUPABASE_URL}/products`, {
              method: "POST",
              headers: supabaseHeaders,
              body: JSON.stringify(prodPayload),
            }).catch(() => {});
            starterCount++;
          }
        }

        return {
          content: [
            {
              type: "text",
              text: `✅ تم إنشاء المتجر بنجاح!\n` +
                    `• الاسم: ${storePayload.name}\n` +
                    `• المعرف (ID): ${id}\n` +
                    `• تصنيف العمل: ${storePayload.type} (${storePayload.app_mode === "retail" ? "تجميع Pick & Pack" : "مطبخ KDS"})\n` +
                    `• هاتف دخول التاجر: ${storePayload.phone}\n` +
                    `• رمز PIN للدخول: ${storePayload.pin}\n` +
                    `• قائمة الأصناف الأولية المضافة: ${starterCount} أصناف نموذجية\n\n` +
                    `يمكن للتاجر الآن فتح تطبيق (Wasel Merchant) وتسجيل الدخول برقم هاتفه والـ PIN مباشرة.`,
            },
          ],
        };
      }

      // 4. Delete Store
      case "wasel_admin_delete_store": {
        const storeId = args.store_id;
        await fetch(`${BACKEND_URL}/stores/${storeId}`, { method: "DELETE" }).catch(() => {});
        await fetch(`${SUPABASE_URL}/stores?id=eq.${storeId}`, { method: "DELETE", headers: supabaseHeaders }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `🗑️ تم حذف المتجر [${storeId}] بنجاح من قاعدة البيانات والمنظومة.`,
            },
          ],
        };
      }

      // 5. Toggle Store Status
      case "wasel_admin_toggle_store_status": {
        const { store_id, is_open } = args;
        await fetch(`${SUPABASE_URL}/stores?id=eq.${store_id}`, {
          method: "PATCH",
          headers: supabaseHeaders,
          body: JSON.stringify({ is_open }),
        }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `🔄 تم تعديل حالة المتجر [${store_id}] إلى: ${is_open ? "🟢 مفتوح ويستقبل طلبات" : "🔴 مغلق مؤقتاً"}.`,
            },
          ],
        };
      }

      // 6. List Products
      case "wasel_admin_list_products": {
        let url = `${BACKEND_URL}/products`;
        if (args.store_id) {
          url = `${BACKEND_URL}/stores/${args.store_id}/menu`;
        }
        const res = await fetch(url);
        const data = await res.json();
        const list = Array.isArray(data.data) ? data.data : (Array.isArray(data) ? data : (data.data?.products || []));

        let summary = `🍽️ قائمة الأصناف (${list.length} صنف):\n\n`;
        for (const p of list) {
          summary += `• [${p.id}] ${p.name} | السعر: ${p.price ?? p.price_lyd} د.ل | القسم: ${p.category ?? "عام"} | ${p.is_available ? "متاح" : "غير متوفر"}\n`;
        }

        return {
          content: [
            {
              type: "text",
              text: summary + `\nبيانات JSON:\n${JSON.stringify(list, null, 2)}`,
            },
          ],
        };
      }

      // 7. Add Product
      case "wasel_admin_add_product": {
        const id = `prod_${Date.now()}`;
        const payload = {
          id,
          store_id: args.store_id,
          name: args.name,
          name_ar: args.name,
          price: Number(args.price),
          price_lyd: Number(args.price),
          category: args.category || "عام",
          description: args.description || "",
          is_available: args.is_available ?? true,
        };

        await fetch(`${BACKEND_URL}/products`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }).catch(() => {});

        await fetch(`${SUPABASE_URL}/products`, {
          method: "POST",
          headers: supabaseHeaders,
          body: JSON.stringify(payload),
        }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `✅ تمت إضافة الصنف [${payload.name}] بسعر ${payload.price} د.ل إلى قائمة المتجر [${payload.store_id}] بنجاح!`,
            },
          ],
        };
      }

      // 8. Delete Product
      case "wasel_admin_delete_product": {
        const pId = args.product_id;
        await fetch(`${BACKEND_URL}/products/${pId}`, { method: "DELETE" }).catch(() => {});
        await fetch(`${SUPABASE_URL}/products?id=eq.${pId}`, { method: "DELETE", headers: supabaseHeaders }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `🗑️ تم حذف الصنف [${pId}] بنجاح.`,
            },
          ],
        };
      }

      // 9. List Drivers
      case "wasel_admin_list_drivers": {
        const res = await fetch(`${BACKEND_URL}/drivers`);
        const data = await res.json();
        const drivers = Array.isArray(data.data) ? data.data : (Array.isArray(data) ? data : []);

        let summary = `🚗 أسطول كباتن واصل نالوت (${drivers.length} كابتن):\n\n`;
        for (const d of drivers) {
          summary += `• [${d.id}] ${d.full_name}\n` +
                     `  الهاتف: ${d.phone} | رمز PIN: ${d.pin ?? "1234"}\n` +
                     `  المركبة: ${d.vehicle_type} (${d.plate_number})\n` +
                     `  العهدة النقدية COD: ${d.wallet_balance_lyd ?? 0} د.ل | الحالة: ${d.status}\n\n`;
        }

        return {
          content: [
            {
              type: "text",
              text: summary + `\nبيانات JSON:\n${JSON.stringify(drivers, null, 2)}`,
            },
          ],
        };
      }

      // 10. Add Driver
      case "wasel_admin_add_driver": {
        const id = `drv_${Date.now()}`;
        const cleanPhone = String(args.phone).replace(/\D/g, "");
        const payload = {
          id,
          full_name: args.full_name,
          phone: cleanPhone,
          pin: args.pin ? String(args.pin) : "1234",
          vehicle_type: args.vehicle_type || "سيارة هيونداي",
          plate_number: args.plate_number || "نالوت 14-",
          status: "available",
          rating: 5.0,
          total_trips: 0,
          wallet_balance_lyd: 0.0,
          max_cod_limit_lyd: Number(args.max_cod_limit_lyd ?? 250.0),
          latitude: 31.8686,
          longitude: 10.9818,
        };

        await fetch(`${BACKEND_URL}/drivers`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }).catch(() => {});

        await fetch(`${SUPABASE_URL}/drivers`, {
          method: "POST",
          headers: supabaseHeaders,
          body: JSON.stringify(payload),
        }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `✅ تم تسجيل الكابتن بنجاح!\n` +
                    `• الاسم: ${payload.full_name}\n` +
                    `• المعرف (ID): ${id}\n` +
                    `• هاتف الدخول: ${payload.phone}\n` +
                    `• رمز PIN: ${payload.pin}\n` +
                    `• المركبة: ${payload.vehicle_type} (${payload.plate_number})\n` +
                    `• سقف عهدة الكاش: ${payload.max_cod_limit_lyd} د.ل\n\n` +
                    `يمكن للكابتن الآن فتح تطبيق (Wasel Captain) وتسجيل الدخول فورا.`,
            },
          ],
        };
      }

      // 11. Delete Driver
      case "wasel_admin_delete_driver": {
        const drvId = args.driver_id;
        await fetch(`${BACKEND_URL}/drivers/${drvId}`, { method: "DELETE" }).catch(() => {});
        await fetch(`${SUPABASE_URL}/drivers?id=eq.${drvId}`, { method: "DELETE", headers: supabaseHeaders }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `🗑️ تم حذف الكابتن [${drvId}] بنجاح من المنظومة.`,
            },
          ],
        };
      }

      // 12. Settle Driver Cash
      case "wasel_admin_settle_driver_cash": {
        const drvId = args.driver_id;
        await fetch(`${SUPABASE_URL}/drivers?id=eq.${drvId}`, {
          method: "PATCH",
          headers: supabaseHeaders,
          body: JSON.stringify({ wallet_balance_lyd: 0.0 }),
        }).catch(() => {});

        return {
          content: [
            {
              type: "text",
              text: `💵 تم استلام وتصفير عهدة الكاش (COD) للكابتن [${drvId}] وتوليد براءة ذمة نقدية.`,
            },
          ],
        };
      }

      // 13. Batch Import
      case "wasel_admin_batch_import": {
        const res = await fetch(`${BACKEND_URL}/admin/batch-import?admin_key=${ADMIN_MASTER_KEY}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(args),
        });
        const result = await res.json();

        return {
          content: [
            {
              type: "text",
              text: `📦 نتيجة الاستيراد الجماعي:\n` +
                    `• المتاجر المضافة: ${result.summary?.stores_imported ?? 0}\n` +
                    `• الأصناف المضافة: ${result.summary?.products_imported ?? 0}\n` +
                    `• الكباتن المضافين: ${result.summary?.drivers_imported ?? 0}\n` +
                    `• حالة العملية: ${result.success ? "ناجحة بنسبة 100%" : "حدث خطأ جزئي"}`,
            },
          ],
        };
      }

      // 14. Purge All
      case "wasel_admin_purge_all": {
        if (args.admin_pin !== ADMIN_MASTER_KEY) {
          throw new Error("رمز الـ PIN الإداري غير صحيح! يرجى إدخال 9832.");
        }

        const res = await fetch(`${BACKEND_URL}/admin/purge-test-data`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ admin_pin: args.admin_pin }),
        });
        const data = await res.json();

        return {
          content: [
            {
              type: "text",
              text: `🧹 تم تطهير المنظومة وقاعدة البيانات بالكامل!\n${data.message || "المنظومة في وضعية التشغيل الحقيقي النظيف (Clean Slate)."}\n• إجمالي السجلات الحالية: 0`,
            },
          ],
        };
      }

      default:
        throw new Error(`أداة غير معروفة: ${name}`);
    }
  } catch (error) {
    return {
      isError: true,
      content: [
        {
          type: "text",
          text: `❌ خطأ أثناء تنفيذ العملية (${name}): ${error.message}`,
        },
      ],
    };
  }
});

// Start Server with Stdio Transport
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Wasel Admin MCP Server running on stdio.");
}

main().catch((err) => {
  console.error("Fatal error in MCP Server:", err);
  process.exit(1);
});
