# LangChain v0 到 v1 迁移计划

## 当前状态分析

### 当前版本
- `langchain==0.3.0`
- `langchain-core==0.3.0`
- `langchain-openai==0.2.0`
- `langchain-anthropic==0.3.0`
- `langgraph==0.2.0`
- `fastmcp==0.1.0`

### 使用范围
仅涉及 1 个文件：
- [backend/app/agent/chain.py](file:///d:/Project/teacher-tool/backend/app/agent/chain.py)

### 当前代码使用模式
1. 使用 `langchain_openai.ChatOpenAI` 和 `langchain_anthropic.ChatAnthropic` 创建 LLM 客户端
2. 使用 `langchain_core.messages` 中的 `HumanMessage`, `SystemMessage`, `AIMessage` 构建消息
3. 使用 `.astream()` 方法流式调用 LLM
4. 使用 `.content` 属性访问消息内容

## LangChain v1 主要变化

### 1. 依赖包版本统一
- `langchain>=1.0.0`
- `langchain-core>=1.0.0`
- `langchain-openai>=1.0.0`
- `langchain-anthropic>=1.0.0`
- `langgraph>=1.0.0`

### 2. 导入路径变化
- `from langchain_core.messages import ...` 保持不变（消息类型仍在 langchain-core）
- `from langchain_openai import ChatOpenAI` 保持不变
- `from langchain_anthropic import ChatAnthropic` 保持不变

### 3. 消息 API 变化（重点）
- **破坏性变更**: `.text()` 方法已废弃，改用 `.text` 属性访问
- `.content` 属性在 v1 中返回结构化内容对象（不是字符串）
- 需要使用 `.text` 属性获取字符串内容

### 4. 流式响应变化
- `.astream()` 返回的 chunk 对象在 v1 中 `.content` 可能是列表或结构化对象
- 需要使用 `.text` 属性获取文本内容

### 5. 模型初始化变化
- v1 推荐使用 `init_chat_model` 统一初始化模型
- 但 `ChatOpenAI` 和 `ChatAnthropic` 仍可直接使用

## 迁移步骤

### 步骤 1: 更新 requirements.txt
```
# AI / Agent
langchain>=1.0.0
langchain-core>=1.0.0
langchain-openai>=1.0.0
langchain-anthropic>=1.0.0
langgraph>=1.0.0
```

### 步骤 2: 更新 chain.py 中的消息内容访问
- 将所有 `chunk.content` 改为 `chunk.text`（因为 v1 中 `.content` 返回结构化对象）
- 确保消息构建部分正确使用 v1 API

### 步骤 3: 更新测试
- 更新 [test_agent_chain.py](file:///d:/Project/teacher-tool/backend/tests/test_agent_chain.py) 确保与 v1 API 兼容
- 验证所有测试通过

### 步骤 4: 运行完整测试
- 执行 `pytest tests/ -v` 确保所有 25 个测试通过
- 验证 Agent 功能正常工作

## 风险评估

### 低风险项
- 导入路径基本保持不变
- 模型初始化方式兼容

### 中风险项
- `.content` 属性在 v1 中行为变化，需要改为 `.text`
- 流式响应的 chunk 对象结构可能变化

### 高风险项
- 无（当前代码使用简单，不涉及复杂 LangChain 功能）

## 验证标准
1. 所有依赖升级到 1.0+
2. 代码中使用 v1 API 规范
3. 所有 25 个测试通过
4. Agent 功能正常工作
