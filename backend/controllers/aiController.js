const { config } = require('../config');
const hfService = require('../services/hfService');

async function parseMenuAI(req, res) {
  try {
    const { image_base64, text_content, store_type = 'restaurant', store_name = '' } = req.body;

    if (!image_base64 && (!text_content || !text_content.trim())) {
      return res.status(400).json({
        success: false,
        error: 'Please provide an image_base64 or text_content of the menu/invoice.'
      });
    }

    const systemPrompt = `You are an expert OCR & catalog digitizer AI for Libyan restaurants, cafeterias, and supermarkets in Nalut (نالوت) and Libya.
Your task is to analyze the provided restaurant menu image/text or supermarket invoice/receipt and extract all items with extreme accuracy.

Rules:
1. Extract item names in authentic Libyan Arabic (e.g. مشويات مشكل، كباب خروف بلدي، بيتزا، شاورما، زيت زيتون نالوت، حليب...).
2. Infer appropriate category (e.g. مشويات جبلية، بيتزا ومعجنات، سندوتشات وسريع، مقبلات ومشروبات، تموينات وبقالة...).
3. Extract or infer price in Libyan Dinars (LYD / د.ل) as a number (e.g. 25.0, 18.5, 4.5).
4. Provide a brief appetizing/clear description in Arabic.
5. Return ONLY a valid, strict JSON object with no markdown fences, formatted as:
{
  "store_name": "extracted or suggested store name",
  "store_type": "${store_type}",
  "total_items_found": 0,
  "items": [
    {
      "nameAr": "اسم الوجبة أو السلعة",
      "category": "القسم المناسب",
      "priceLyd": 25.00,
      "descAr": "وصف الوجبة والمكونات",
      "unit": "وجبة / صحن / قطعة / لتر"
    }
  ]
}`;

    const userMessageContent = [];
    if (text_content) {
      userMessageContent.push({
        type: 'text',
        text: `Here is the menu or invoice text to extract:\n\n${text_content}`
      });
    }
    if (image_base64) {
      const formattedImageUrl = image_base64.startsWith('data:')
        ? image_base64
        : `data:image/jpeg;base64,${image_base64}`;
      userMessageContent.push({
        type: 'image_url',
        image_url: { url: formattedImageUrl }
      });
    }

    const aiPayload = {
      model: process.env.AI_MODEL || 'gemini-3.7-flash',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessageContent.length === 1 && userMessageContent[0].type === 'text' ? userMessageContent[0].text : userMessageContent }
      ],
      temperature: 0.1
    };

    const aiRes = await fetch(process.env.AI_ENDPOINT || 'http://127.0.0.1:8045/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.AI_API_KEY || 'sk-37c5462abaf34c58a8f05854cdd8a518'}`
      },
      body: JSON.stringify(aiPayload)
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      throw new Error(`AI Gateway responded with status ${aiRes.status}: ${errText}`);
    }

    const aiJson = await aiRes.json();
    const rawContent = aiJson.choices?.[0]?.message?.content || '{}';

    let parsedData = {};
    try {
      const cleaned = rawContent.replace(/```json/gi, '').replace(/```/g, '').trim();
      parsedData = JSON.parse(cleaned);
    } catch(parseErr) {
      const jsonMatch = rawContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        parsedData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Failed to parse structured JSON from AI output');
      }
    }

    res.json({
      success: true,
      source: 'Gemini 3.7 Flash AI OCR',
      data: parsedData
    });
  } catch (err) {
    console.error('[AI Menu OCR Error]:', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
}

async function bulkAddProducts(req, res, db) {
  try {
    const storeId = req.params.id;
    const { items = [] } = req.body;
    const store = db.stores.find(s => s.id === storeId);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    const addedProducts = [];
    items.forEach((item, idx) => {
      const newProd = {
        id: `prod_${require('uuid').v4().substring(0, 8)}`,
        store_id: store.id,
        name: item.nameAr || item.name || `صنف ${idx + 1}`,
        description: item.descAr || item.description || '',
        price_lyd: parseFloat(item.priceLyd || item.price_lyd || 10.0),
        category: item.category || 'عام',
        is_available: true,
        image_url: item.imageUrl || 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
        created_at: new Date().toISOString()
      };
      db.products.push(newProd);
      addedProducts.push(newProd);
    });

    res.status(201).json({
      success: true,
      message: `Successfully added ${addedProducts.length} items to ${store.name}`,
      count: addedProducts.length,
      data: addedProducts
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function enhanceProductDescription(req, res) {
  try {
    const { productName, category, productId } = req.body;

    if (!productName) {
      return res.status(400).json({ success: false, error: 'Product name is required.' });
    }

    // Integration is asynchronous via async/await and non-blocking axios calls.
    const enhancedDesc = await hfService.enhanceDescription(productName, category || 'عام');

    res.json({
      success: true,
      enhanced_description: enhancedDesc,
      source: 'Hugging Face LLaMA-E'
    });
  } catch (err) {
    console.error('[AI Enhance Error]:', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
}

module.exports = {
  parseMenuAI,
  bulkAddProducts,
  enhanceProductDescription
};
