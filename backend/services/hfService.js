/**
 * ============================================================================
 * HUGGING FACE / AI DESCRIPTION ENHANCEMENT SERVICE
 * Enhances menu item and product descriptions in Libyan Arabic
 * ============================================================================
 */

class HfService {
  async enhanceDescription(productName, category = 'عام') {
    try {
      // If an external Hugging Face or AI endpoint is configured:
      if (process.env.HF_API_KEY && process.env.HF_API_ENDPOINT) {
        const response = await fetch(process.env.HF_API_ENDPOINT, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.HF_API_KEY}`
          },
          body: JSON.stringify({
            inputs: `صف وجبة أو منتج ${productName} في قسم ${category} بنبرة شهية وموجزة باللهجة الليبية ونالوت:`
          })
        });

        if (response.ok) {
          const result = await response.json();
          if (Array.isArray(result) && result[0]?.generated_text) {
            return result[0].generated_text.trim();
          }
        }
      }

      // Safe, authentic fallback template for Nalut catalog items
      const categoryDesc = {
        'مشويات': 'لحم طازج متبل بالبهارات الجبلية الأصيلة ومشوي على الفحم مع التغليف الساخن.',
        'وجبات سريعة': 'محضر طازجاً من أجود المكونات المحلية مع الصلصات الخاصة.',
        'بيتزا': 'عجينة طازجة مخبوزة على الحطب مع جبنة الموزاريلا والصلصة الإيطالية الخاصة.',
        'شاورما': 'شاورما متبلة بتتبيلة نالوت الخاصة مع خبز طازج وثومية.',
        'مشروبات': 'مشروب منعش يقدم بارداً.',
        'بقالة': 'منتج تمويني عالي الجودة ومضمون من أفضل الموردين في نالوت.'
      };

      const matchedDesc = Object.entries(categoryDesc).find(([key]) => category.includes(key));
      return matchedDesc 
        ? `${productName} الشهي - ${matchedDesc[1]}`
        : `${productName} طازج ومعد بأعلى معايير الجودة في نالوت.`;
    } catch (err) {
      console.warn('[HfService] Fallback description used:', err.message);
      return `${productName} طازج ومعد بأعلى معايير الجودة في نالوت.`;
    }
  }
}

module.exports = new HfService();
