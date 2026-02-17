import { registerCompositeSearchTool } from './tools/compositeSearch.js';

const bigclawPlugin = {
  id: "bigclaw",
  name: "BigClaw Search",
  description: "复合搜索工具 - 高德地图 + 百度AI搜索",
  kind: "tools",
  configSchema: { type: "object" },
  
  register(api) {
    console.log("[DEBUG] bigclaw plugin register called");
    
    // Register all tools
    registerCompositeSearchTool(api);
    
    console.log("[DEBUG] bigclaw plugin registration completed");
  }
};

export default bigclawPlugin;