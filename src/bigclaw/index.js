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
      description: "复合搜索：高德 POI（地点/周边美食等）或百度通用搜索。建议用结构化入参 region/landmark/keyword 精确指定区域与地标，减少异地同名偏差。",
      
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "自然语言搜索内容。当不填 region/landmark/keyword 时使用，会尝试从文本解析；若已填结构化字段则仅作备用或百度搜索用。"
          },
          region: {
            type: "string",
            description: "限定区域（省/市/县/区），如「惠安县」「泉州市」。高德仅在该区域内搜索，避免异地同名 POI。"
          },
          landmark: {
            type: "string",
            description: "地标或 POI 名称，如「欧乐堡」「西湖」。与 region 同时使用时，先在区域内定位此地标，再在其周边搜 keyword。"
          },
          keyword: {
            type: "string",
            description: "搜索类别/关键词，如「美食」「酒店」「景点」。表示「某地标附近搜某类」时的类别。"
          },
          source: {
            type: "string",
            description: "搜索来源: auto（按内容自动选）/ gaode（高德 POI）/ baidu（百度通用）",
            enum: ["auto", "gaode", "baidu"]
          }
        }
      },
      
      async execute(_id, params, runSignal, _onUpdate) {
        console.log("[DEBUG] composite_search execute called:", JSON.stringify(params));
        
        const query = (params?.query || "").trim();
        const region = (params?.region || "").trim();
        const landmark = (params?.landmark || "").trim();
        const keyword = (params?.keyword || "").trim();
        const hasStructured = region || landmark || keyword;
        
        if (!query && !hasStructured) {
          return { content: [{ type: "text", text: "错误: 需要提供 query，或至少提供 region/landmark/keyword 之一" }] };
        }
        
        let source = params?.source || "auto";
        const effectiveQuery = query || [region, landmark, keyword].filter(Boolean).join(" ");
        
        if (source === "auto") {
          const poiLike = /酒店|餐厅|路线|地图|地址|在哪|位置|旅游|景点|日料|日式|美食|购物|打车|公交|地铁/;
          if (poiLike.test(effectiveQuery) || keyword) {
            source = "gaode";
          } else {
            source = "baidu";
          }
        }
        
        console.log("[DEBUG] Selected source:", source, "structured:", { region, landmark, keyword });
        
        try {
          if (source === "gaode") {
            const gaodeKey = process.env.GAODE_API_KEY;
            if (!gaodeKey) {
              return { content: [{ type: "text", text: "错误: GAODE_API_KEY 未配置" }] };
            }
            
            let cityLimit = region || null;
            let location = landmark || "北京";
            let keywords = keyword || "美食";
            let regionMatch = null;
            
            if (hasStructured && (region || landmark || keyword)) {
              // 结构化入参优先：大模型直接传入，不再从 query 解析
              if (!cityLimit && query) {
                regionMatch = query.match(/([一-龥]+(?:省|市|县|区|镇))/g);
                if (regionMatch && regionMatch.length > 0) {
                  cityLimit = regionMatch[regionMatch.length - 1];
                }
              }
              if (!location && query) location = query;
              if (!keywords && query) keywords = query;
            } else if (query) {
              // 回退：从 query 解析
              const poiKeywords = ["餐厅", "饭店", "美食", "酒店", "景点", "商店", "超市", "医院", "学校", "咖啡", "奶茶"];
              const hasPoiKeyword = poiKeywords.some(k => query.includes(k));
              if (hasPoiKeyword) {
                regionMatch = query.match(/([一-龥]+(?:省|市|县|区|镇))/g);
                if (regionMatch && regionMatch.length > 0) {
                  cityLimit = regionMatch[regionMatch.length - 1];
                }
                const nearMatch = query.match(/^(.+?)(附近|周边|周围|以内|周围)(.+)?$/);
                if (nearMatch) {
                  location = nearMatch[1].trim();
                  keywords = (nearMatch[3] || "").trim() || "美食";
                } else {
                  location = query;
                  keywords = "美食";
                }
              } else {
                location = query;
                keywords = query;
              }
            }
            
            const poiTypes = ["餐厅", "饭店", "美食", "酒店", "景点", "商店", "超市", "医院", "学校", "咖啡", "奶茶"];
            const hasPoiKeyword = poiTypes.some(k => (keywords || location || query).includes(k));
            
            if (hasPoiKeyword || hasStructured) {
              console.log("[DEBUG] Gaode - Location:", location, "Keywords:", keywords, "cityLimit:", cityLimit);
              
              let coords = null;
              const landmarkToUse = landmark || (cityLimit && regionMatch ? (() => {
                let ln = location;
                for (const r of regionMatch) ln = ln.replace(r, "");
                return ln.trim() || location;
              })() : null);
              
              if (cityLimit) {
                coords = await geocode(cityLimit, "中国", gaodeKey, runSignal);
                if (coords && landmarkToUse) {
                  const landmarkPois = await searchPOI(coords, landmarkToUse, "050000", 15000, gaodeKey, runSignal);
                  if (landmarkPois.length > 0 && landmarkPois[0].location) {
                    coords = landmarkPois[0].location;
                  }
                  const pois = await searchPOI(coords, keywords, "050000", 3000, gaodeKey, runSignal);
                  if (pois.length > 0) {
                    const resultText = formatPOIResults(pois, keywords, location);
                    return { content: [{ type: "text", text: resultText }] };
                  }
                }
                if (coords) {
                  const pois = await searchPOI(coords, keywords, "050000", 5000, gaodeKey, runSignal);
                  if (pois.length > 0) {
                    const resultText = formatPOIResults(pois, keywords, cityLimit);
                    return { content: [{ type: "text", text: resultText }] };
                  }
                }
              }
              if (!coords) {
                coords = await geocode(location, cityLimit || "中国", gaodeKey, runSignal);
              }
              if (coords) {
                const pois = await searchPOI(coords, keywords, "050000", 5000, gaodeKey, runSignal);
                if (pois.length > 0) {
                  const resultText = formatPOIResults(pois, keywords, location);
                  return { content: [{ type: "text", text: resultText }] };
                }
              }
            }
            
            // 回退到普通文本搜索（同样带上区域限定，避免异地结果）
            let textUrl = `https://restapi.amap.com/v5/place/text?keywords=${encodeURIComponent(effectiveQuery || query)}&key=${gaodeKey}&offset=10`;
            if (typeof cityLimit === "string" && cityLimit) {
              textUrl += `&city=${encodeURIComponent(cityLimit)}`;
            }
            const response = await fetchWithTimeout(textUrl, 10000, {}, runSignal);
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
            // 使用 web_search 接口（仅搜索、返回引用列表），比 chat/completions 更稳定、时延更低
            const url = "https://qianfan.baidubce.com/v2/ai_search/web_search";
            const q = (effectiveQuery || query).slice(0, 72);
            const payload = {
              messages: [{ role: "user", content: q }],
              edition: "lite",
              search_source: "baidu_search_v2",
              resource_type_filter: [{ type: "web", top_k: 10 }]
            };
            // 正常调用秒级返回。不传 runSignal 给 fetch，避免网关提前 abort 导致外层返回「搜索超时」；仅用 8s×2 本地超时
            const maxAttempts = 2;
            const timeoutPerAttempt = 8000;
            let lastError = null;
            for (let attempt = 1; attempt <= maxAttempts; attempt++) {
              if (runSignal?.aborted) throw Object.assign(new Error("aborted"), { name: "AbortError" });
              try {
                console.log("[DEBUG] Baidu web_search attempt", attempt, "/", maxAttempts, "query:", q);
                const response = await fetchWithTimeout(url, timeoutPerAttempt, {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${baiduApiKey}`
                  },
                  body: JSON.stringify(payload)
                }, undefined);
                const data = await response.json();
                if (data.code !== undefined && data.code !== 0) {
                  lastError = data.message || String(data.code);
                  if (attempt < maxAttempts) {
                    await new Promise(r => setTimeout(r, Math.min(1000 * Math.pow(2, attempt - 1), 5000)));
                    continue;
                  }
                  return { content: [{ type: "text", text: `百度搜索失败: ${lastError}` }] };
                }
                const refs = data.references || [];
                if (refs.length === 0) {
                  return { content: [{ type: "text", text: "未找到相关结果，请换关键词再试。" }] };
                }
                let result = `【百度搜索】\n\n共 ${refs.length} 条结果：\n\n`;
                refs.slice(0, 10).forEach((ref, i) => {
                  result += `${i + 1}. ${ref.title || "无标题"}\n`;
                  result += `   ${ref.url || ""}\n`;
                  if (ref.content) result += `   ${ref.content.slice(0, 200)}${ref.content.length > 200 ? "…" : ""}\n`;
                  result += "\n";
                });
                return { content: [{ type: "text", text: result }] };
              } catch (err) {
                lastError = err?.message ?? String(err);
                const isAbort = err?.name === "AbortError" || /aborted|timeout/i.test(lastError);
                console.log("[DEBUG] Baidu attempt", attempt, "failed:", lastError, isAbort ? "(timeout/abort)" : "");
                if (runSignal?.aborted) throw err;
                if (attempt < maxAttempts) {
                  await new Promise(r => setTimeout(r, Math.min(1000 * Math.pow(2, attempt - 1), 5000)));
                  continue;
                }
                if (isAbort) {
                  return { content: [{ type: "text", text: "百度搜索多次超时，请稍后重试或换更短的关键词。" }] };
                }
                return { content: [{ type: "text", text: `搜索错误: ${lastError}` }] };
              }
            }
            return { content: [{ type: "text", text: `百度搜索失败: ${lastError || "未知错误"}` }] };
          }
          
          return { content: [{ type: "text", text: "未知搜索源" }] };
          
        } catch (error) {
          const msg = error?.message ?? String(error);
          const isAbort = error?.name === "AbortError" || /aborted/i.test(msg);
          console.log("[DEBUG] Search error:", msg, isAbort ? "(timeout/abort)" : "");
          if (isAbort) {
            return { content: [{ type: "text", text: "搜索超时，请稍后重试或换更短的关键词再试。" }] };
          }
          return { content: [{ type: "text", text: `搜索错误: ${msg}` }] };
        }
      }
    });
  }
};

async function geocode(address, city, apiKey, runSignal) {
  const url = `https://restapi.amap.com/v3/geocode/geo?address=${encodeURIComponent(address)}&city=${encodeURIComponent(city)}&key=${apiKey}`;
  console.log("[DEBUG] geocode url:", url.substring(0, 100));
  
  try {
    const response = await fetchWithTimeout(url, 10000, {}, runSignal);
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

async function searchPOI(location, keywords, types, radius, apiKey, runSignal) {
  const url = `https://restapi.amap.com/v5/place/text?keywords=${encodeURIComponent(keywords)}&types=${types}&location=${location}&radius=${radius}&offset=50&key=${apiKey}`;
  console.log("[DEBUG] searchPOI url:", url.substring(0, 100));
  
  try {
    const response = await fetchWithTimeout(url, 10000, {}, runSignal);
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

// 合并「本机超时」与「run 的 AbortSignal」（用户停止 / run 超时），任一触发即中止请求
function combineSignal(timeoutMs, runSignal) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  const onAbort = () => {
    clearTimeout(timeoutId);
    controller.abort();
  };
  if (runSignal?.aborted) {
    clearTimeout(timeoutId);
    controller.abort();
    return controller.signal;
  }
  if (runSignal) {
    runSignal.addEventListener("abort", onAbort, { once: true });
  }
  controller.signal.addEventListener("abort", () => {
    clearTimeout(timeoutId);
    if (runSignal) runSignal.removeEventListener("abort", onAbort);
  }, { once: true });
  return controller.signal;
}

async function fetchWithTimeout(url, timeoutMs, options = {}, runSignal) {
  const signal = combineSignal(timeoutMs, runSignal);
  const response = await fetch(url, { ...options, signal });
  if (!response.ok) {
    await response.body?.cancel?.().catch(() => {});
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response;
}

export default bigclawPlugin;