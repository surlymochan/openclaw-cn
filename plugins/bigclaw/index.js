import crypto from 'crypto';

const bigclawPlugin = {
  id: "bigclaw",
  name: "BigClaw Search",
  description: "复合搜索工具 - 高德地图 + 百度AI搜索",
  kind: "tools",
  configSchema: { type: "object" },
  
  register(api) {
    console.log("[DEBUG] bigclaw register called");
    
    api.registerTool({
      name: "composite_search",
      label: "Composite Search",
      description: "复合搜索工具 - 支持高德地图POI搜索和百度AI通用搜索",
      
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "搜索查询" },
          source: { 
            type: "string", 
            description: "搜索来源: auto/gaode/baidu",
            enum: ["auto", "gaode", "baidu"]
          }
        }
      },
      
      async execute(_id, params) {
        console.log("[DEBUG] composite_search execute called:", JSON.stringify(params));
        
        const query = params?.query;
        if (!query) {
          return { content: [{ type: "text", text: "错误: 需要提供搜索查询" }] };
        }
        
        let source = params?.source || "auto";
        
        // 自动路由逻辑
        if (source === "auto") {
          if (query.match(/酒店|餐厅|路线|地图|地址|在哪|位置|旅游|景点|日料|日式|美食|购物|打车|公交|地铁/)) {
            source = "gaode";
          } else {
            source = "baidu";
          }
        }
        
        console.log("[DEBUG] Selected source:", source);
        
        try {
          if (source === "gaode") {
            const gaodeKey = process.env.GAODE_API_KEY;
            if (!gaodeKey) {
              return { content: [{ type: "text", text: "错误: GAODE_API_KEY 未配置" }] };
            }
            
            // 尝试 POI 搜索
            const poiKeywords = ["餐厅", "饭店", "美食", "酒店", "景点", "商店", "超市", "医院", "学校", "咖啡", "奶茶"];
            const hasPoiKeyword = poiKeywords.some(keyword => query.includes(keyword));
            
            if (hasPoiKeyword) {
              // 提取位置和关键词
              let location = "北京";
              let keywords = query;
              
              // 简单的位置提取
              const locationPatterns = [
                /(.*?)(?:附近|周边|周围|以内|内|在|于)/,
                /(.*?)(?:市|区|县|镇|街道|路|巷|街)/
              ];
              
              for (const pattern of locationPatterns) {
                const match = query.match(pattern);
                if (match) {
                  location = match[1].trim();
                  keywords = query.replace(match[0], "").trim() || "美食";
                  break;
                }
              }
              
              console.log("[DEBUG] Gaode - Location:", location, "Keywords:", keywords);
              
              // Geocoding
              const coords = await geocode(location, "中国", gaodeKey);
              if (coords) {
                const pois = await searchPOI(coords, keywords, "050000", 5000, gaodeKey);
                if (pois.length > 0) {
                  const resultText = formatPOIResults(pois, keywords, location);
                  return { content: [{ type: "text", text: resultText }] };
                }
              }
            }
            
            // 回退到普通文本搜索
            const url = `https://restapi.amap.com/v5/place/text?keywords=${encodeURIComponent(query)}&key=${gaodeKey}&offset=10`;
            const response = await fetchWithTimeout(url, 10000);
            const data = await response.json();
            
            if (data.status != "1") {
              return { content: [{ type: "text", text: `高德搜索失败: ${data.info || "未知错误"}` }] };
            }
            
            const pois = data.pois || [];
            if (pois.length === 0) {
              return { content: [{ type: "text", text: "高德地图未找到相关结果" }] };
            }
            
            const resultText = formatPOIResults(pois, query, "附近");
            return { content: [{ type: "text", text: resultText }] };
          }
          
          if (source === "baidu") {
            const baiduApiKey = process.env.BAIDU_API_KEY;
            if (!baiduApiKey) {
              return { content: [{ type: "text", text: "错误: BAIDU_API_KEY 未配置" }] };
            }
            
            const url = "https://qianfan.baidubce.com/v2/ai_search/chat/completions";
            const payload = {
              messages: [{ content: query, role: "user" }],
              model: "ernie-4.5-turbo-32k",
              search_source: "baidu_search_v2",
              resource_type_filter: [{ type: "web", top_k: 10 }]
            };
            
            console.log("[DEBUG] Baidu API call with query:", query);
            
            const response = await fetchWithTimeout(url, 15000, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${baiduApiKey}`
              },
              body: JSON.stringify(payload)
            });
            
            const data = await response.json();
            
            if (data.choices && data.choices.length > 0) {
              const content = data.choices[0].message.content;
              let result = `【百度AI搜索】\n\n${content}\n\n`;
              
              if (data.references && data.references.length > 0) {
                result += "参考资料:\n";
                data.references.slice(0, 5).forEach((ref, index) => {
                  result += `${index + 1}. [${ref.title}](${ref.url})\n`;
                });
              }
              
              return { content: [{ type: "text", text: result }] };
            } else {
              return { content: [{ type: "text", text: `百度搜索失败: ${data.message || "未知错误"}` }] };
            }
          }
          
          return { content: [{ type: "text", text: "未知搜索源" }] };
          
        } catch (error) {
          console.log("[DEBUG] Search error:", error.message);
          return { content: [{ type: "text", text: `搜索错误: ${error.message}` }] };
        }
      }
    });
  }
};

async function geocode(address, city, apiKey) {
  const url = `https://restapi.amap.com/v3/geocode/geo?address=${encodeURIComponent(address)}&city=${encodeURIComponent(city)}&key=${apiKey}`;
  console.log("[DEBUG] geocode url:", url.substring(0, 100));
  
  try {
    const response = await fetchWithTimeout(url, 10000);
    const data = await response.json();
    console.log("[DEBUG] geocode response status:", data.status);
    
    if (data.status != "1" || !data.geocodes || data.geocodes.length === 0) {
      console.log("[DEBUG] geocode failed:", data.info);
      return null;
    }
    
    return data.geocodes[0].location;
  } catch (error) {
    console.log("[DEBUG] geocode error:", error.message);
    return null;
  }
}

async function searchPOI(location, keywords, types, radius, apiKey) {
  const url = `https://restapi.amap.com/v5/place/text?keywords=${encodeURIComponent(keywords)}&types=${types}&location=${location}&radius=${radius}&offset=50&key=${apiKey}`;
  console.log("[DEBUG] searchPOI url:", url.substring(0, 100));
  
  try {
    const response = await fetchWithTimeout(url, 10000);
    const data = await response.json();
    console.log("[DEBUG] searchPOI response status:", data.status);
    
    if (data.status != "1") {
      console.log("[DEBUG] searchPOI failed:", data.info);
      return [];
    }
    
    return data.pois || [];
  } catch (error) {
    console.log("[DEBUG] searchPOI error:", error.message);
    return [];
  }
}

function formatPOIResults(pois, keywords, location) {
  let text = `在"${location}"找到${pois.length}个"${keywords}"相关结果:\n\n`;
  
  for (let i = 0; i < Math.min(pois.length, 10); i++) {
    const p = pois[i];
    text += `${i + 1}. ${p.name}\n`;
    if (p.address) text += `   地址: ${p.address}\n`;
    if (p.type) text += `   类型: ${p.type}\n`;
    if (p.biz_ext?.rating) text += `   评分: ${p.biz_ext.rating}分\n`;
    if (p.tel) text += `   电话: ${p.tel}\n`;
    text += `\n`;
  }
  
  return text;
}

async function fetchWithTimeout(url, timeoutMs, options = {}) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    return response;
  } finally {
    clearTimeout(timeoutId);
  }
}

export default bigclawPlugin;