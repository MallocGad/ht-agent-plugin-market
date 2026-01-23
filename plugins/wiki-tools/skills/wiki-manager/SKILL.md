---
name: wiki-manager
description: Comprehensive Confluence Wiki management tool for reading, updating, creating, and managing Wiki pages. Use when Claude needs to work with Confluence Wiki pages for (1) Creating new pages or sub-pages, (2) Fetching page content in HTML/Markdown format, (3) Updating page content or title, (4) Appending content to existing pages, (5) Extracting page IDs from URLs, or (6) Managing Wiki documentation. Triggers include "创建 Wiki", "新建 Wiki", "更新 Wiki", "获取 Wiki 页面", "同步到 Wiki", "Wiki 文档", or any Wiki-related operations.
---

# Wiki Manager

管理 Confluence Wiki 页面的完整工具集，支持创建、读取、更新、追加内容等操作。

**推荐使用 Confluence HTML Storage Format** 以获得最佳兼容性和格式控制。

## Quick Start

### 环境变量配置

在使用前，必须配置以下环境变量：

```bash
export WIKI_BASE_URL="https://wiki.*.com"  # Confluence 基础 URL（必需）
export WIKI_TOKEN="your-api-token-here"         # Confluence API Token（必需）

# 可选：配置默认空间和父页面，简化命令行操作
export WIKI_DEFAULT_SPACE="~ht"           # 默认空间 key（可选）
export WIKI_DEFAULT_PARENT_PAGE="*"     # 默认父页面 ID（可选）
```

当设置了 `WIKI_DEFAULT_SPACE` 和 `WIKI_DEFAULT_PARENT_PAGE` 后，创建页面时无需重复指定。

### 安装依赖

脚本需要以下 Python 库：

```bash
pip install httpx markdownify markdown
```

## Core Operations

本 skill 提供四个核心操作命令。

### 1. 创建新页面 (create)

在 Confluence 空间中创建新页面或子页面。

**基本用法：**

```bash
# 创建顶级页面（需要指定空间）
python scripts/wiki_manager.py create \
  --title "页面标题" \
  --space "~ht" \
  --format html \
  --content "<h1>页面内容</h1>"

# 如果配置了默认空间，可以省略 --space（使用 WIKI_DEFAULT_SPACE）
python scripts/wiki_manager.py create \
  --title "页面标题" \
  --format html \
  --content "<h1>页面内容</h1>"

# 创建子页面（指定父页面 ID）
python scripts/wiki_manager.py create \
  --title "子页面标题" \
  --space "~ht" \
  --parent 12345678 \
  --format html \
  --file content.html

# 如果配置了默认空间和默认父页面，可以最简化（只需指定标题）
python scripts/wiki_manager.py create \
  --title "子页面标题" \
  --file content.html

# 创建大内容页面（自动分批）
python scripts/wiki_manager.py create \
  --title "大型文档" \
  --space "~ht" \
  --format html \
  --file large_content.html \
  --chunk-size 1048576
```

**选项：**

- `--title TEXT` 或 `-t TEXT` - 页面标题（必需）
- `--space TEXT` 或 `-s TEXT` - 空间 key（可选，如未指定则使用 WIKI_DEFAULT_SPACE 环境变量）
- `--content TEXT` 或 `-c TEXT` - 直接提供内容文本
- `--file FILE` 或 `-f FILE` - 从文件读取内容
- `--format {html|markdown}` - 内容格式（默认: html，推荐）
- `--parent PAGE_ID` 或 `-p PAGE_ID` - 父页面 ID（可选，如未指定则使用 WIKI_DEFAULT_PARENT_PAGE 环境变量）
- `--chunk-size BYTES` - 当内容超过此字节数时自动分批创建（例如: 1048576 表示 1MB）

**分批创建说明：**

当页面内容过大时，Confluence API 可能会超时或失败。使用 `--chunk-size` 参数可以：
- 第一次创建页面时添加部分内容
- 后续自动追加剩余内容
- 按指定字节大小智能切分（确保 UTF-8 编码不被破坏）
- 显示分批进度和统计信息

**示例：**

```bash
# 方案 1: 每次都指定空间和父页面
python scripts/wiki_manager.py create \
  --title "功能文档" \
  --space "~ht" \
  --parent 217851921 \
  --format html \
  --content "<h1>功能列表</h1>..."

# 方案 2: 配置默认值，简化命令（推荐）
export WIKI_DEFAULT_SPACE="~ht"
export WIKI_DEFAULT_PARENT_PAGE="217851921"

# 现在只需指定标题和内容
python scripts/wiki_manager.py create \
  -t "功能文档" \
  --format html \
  -c "<h1>功能列表</h1>..."

# 从文件创建页面
python scripts/wiki_manager.py create \
  -t "需求文档" \
  --format html \
  -f requirements.html

# 创建子页面
python scripts/wiki_manager.py create \
  -t "实施方案" \
  --format html \
  -c "<p>这是子页面内容</p>"

# 创建大内容页面（分批处理，每批 1MB）
python scripts/wiki_manager.py create \
  -t "大型设计文档" \
  --format html \
  -f large_design.html \
  --chunk-size 1048576
```

### 2. 获取页面内容 (get)

从 Confluence 获取页面内容，支持多种输出格式。

**基本用法：**

```bash
# 使用页面 ID（推荐获取 storage 格式）
python scripts/wiki_manager.py get --page-id 12345678 --format storage

# 使用页面 URL（自动提取 ID）
python scripts/wiki_manager.py get --url "https://wiki.*.com/pages/12345678" --format storage
```

**选项：**

- `--format {storage|markdown|view}` - 输出格式（默认: storage，推荐）
  - `storage`: Confluence 存储格式（HTML Storage Format）**[推荐]**
  - `markdown`: 转换为 Markdown 格式
  - `view`: 渲染后的 HTML
- `--output FILE` 或 `-o FILE` - 保存内容到文件
- `--json` - 输出完整 JSON 格式（包含元数据）

**示例：**

```bash
# 获取 HTML Storage Format 内容并保存
python scripts/wiki_manager.py get --url "https://wiki.*.com/pages/12345678" --format storage -o content.html

# 获取完整 JSON 信息
python scripts/wiki_manager.py get --page-id 12345678 --json
```

### 3. 更新页面内容 (update)

更新 Confluence 页面的内容和/或标题，支持覆盖和追加模式。

**推荐使用 HTML 格式以获得最佳兼容性。**

**基本用法：**

```bash
# 从文本直接更新（HTML 格式）
python scripts/wiki_manager.py update --page-id 12345678 --format html --content "<p>新内容</p>"

# 从文件读取内容（HTML 格式）
python scripts/wiki_manager.py update --page-id 12345678 --format html --file content.html

# 使用 URL（自动提取 ID）
python scripts/wiki_manager.py update --url "https://wiki.*.com/pages/12345678" --format html --file content.html
```

**选项：**

- `--content TEXT` 或 `-c TEXT` - 直接提供内容文本
- `--file FILE` 或 `-f FILE` - 从文件读取内容
- `--title TEXT` 或 `-t TEXT` - 更新页面标题
- `--format {html|markdown}` - 内容格式（默认: html，推荐）
- `--append` 或 `-a` - 追加模式（追加到现有内容末尾，而非覆盖）

**示例：**

```bash
# 覆盖页面内容（HTML 格式）
python scripts/wiki_manager.py update --page-id 12345678 --format html -f content.html

# 追加内容到页面末尾（HTML 格式）
python scripts/wiki_manager.py update --page-id 12345678 --format html -c "<h2>新增章节</h2><p>新增内容</p>" --append

# 只更新标题
python scripts/wiki_manager.py update --page-id 12345678 --title "新标题"

# 同时更新标题和内容
python scripts/wiki_manager.py update --page-id 12345678 -t "新标题" --format html -f content.html

# 使用 Markdown 格式（备选）
python scripts/wiki_manager.py update --page-id 12345678 --format markdown -c "## 标题\n\n内容"
```

### 4. 提取页面 ID (extract-id)

从 Confluence URL 提取页面 ID（用于其他操作）。

**用法：**

```bash
python scripts/wiki_manager.py extract-id "https://wiki.*.com/pages/12345678"
# 输出: 12345678

python scripts/wiki_manager.py extract-id "https://wiki.*.com/pages/viewpage.action?pageId=12345678"
# 输出: 12345678
```

## Confluence HTML Storage Format

Confluence 使用 Storage Format（特殊的 XHTML）存储页面内容。以下是常用标签：

### 基本文本格式

```html
<!-- 段落 -->
<p>这是一个段落</p>

<!-- 标题 -->
<h1>一级标题</h1>
<h2>二级标题</h2>
<h3>三级标题</h3>

<!-- 文本样式 -->
<strong>粗体</strong>
<em>斜体</em>
<u>下划线</u>
<s>删除线</s>

<!-- 换行 -->
<br/>
```

### 列表

```html
<!-- 无序列表 -->
<ul>
  <li>项目 1</li>
  <li>项目 2</li>
  <li>项目 3</li>
</ul>

<!-- 有序列表 -->
<ol>
  <li>步骤 1</li>
  <li>步骤 2</li>
  <li>步骤 3</li>
</ol>
```

### 表格

```html
<table>
  <tbody>
    <tr>
      <th>表头 1</th>
      <th>表头 2</th>
      <th>表头 3</th>
    </tr>
    <tr>
      <td>单元格 1</td>
      <td>单元格 2</td>
      <td>单元格 3</td>
    </tr>
    <tr>
      <td>数据 A</td>
      <td>数据 B</td>
      <td>数据 C</td>
    </tr>
  </tbody>
</table>
```

### 代码块

```html
<!-- 代码块（带语法高亮） -->
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">python</ac:parameter>
  <ac:plain-text-body><![CDATA[
def hello_world():
    print("Hello, World!")
    return True
]]></ac:plain-text-body>
</ac:structured-macro>

<!-- 支持的语言：python, java, javascript, bash, sql, json, xml, html 等 -->
```

### 提示框

```html
<!-- 信息提示框 -->
<ac:structured-macro ac:name="info">
  <ac:rich-text-body>
    <p>这是一条信息提示</p>
  </ac:rich-text-body>
</ac:structured-macro>

<!-- 警告提示框 -->
<ac:structured-macro ac:name="warning">
  <ac:rich-text-body>
    <p>这是一条警告信息</p>
  </ac:rich-text-body>
</ac:structured-macro>

<!-- 注意提示框 -->
<ac:structured-macro ac:name="note">
  <ac:rich-text-body>
    <p>这是一条注意事项</p>
  </ac:rich-text-body>
</ac:structured-macro>

<!-- 成功提示框 -->
<ac:structured-macro ac:name="tip">
  <ac:rich-text-body>
    <p>这是一条成功提示</p>
  </ac:rich-text-body>
</ac:structured-macro>
```

### 链接

```html
<!-- 外部链接 -->
<a href="https://example.com">链接文本</a>

<!-- 内部页面链接 -->
<ac:link>
  <ri:page ri:content-title="目标页面标题"/>
  <ac:plain-text-link-body><![CDATA[链接文本]]></ac:plain-text-link-body>
</ac:link>
```

### 展开折叠块

```html
<ac:structured-macro ac:name="expand">
  <ac:parameter ac:name="title">点击展开</ac:parameter>
  <ac:rich-text-body>
    <p>这里是折叠的内容</p>
    <p>可以包含任何其他 HTML 元素</p>
  </ac:rich-text-body>
</ac:structured-macro>
```

## Usage Examples

### 场景 1: 创建新页面

```bash
# 创建简单页面
python scripts/wiki_manager.py create \
  --title "Wiki Manager 测试页面" \
  --space "~ht" \
  --format html \
  --content "<h1>测试页面</h1><p>这是一个新创建的页面</p>"

# 创建子页面
python scripts/wiki_manager.py create \
  --title "子页面" \
  --space "~ht" \
  --parent 12345678 \
  --format html \
  --content "<p>这是 12345678 页面的子页面</p>"
```

### 场景 2: 创建包含表格和代码块的页面

```bash
# 创建 HTML 内容文件
cat > content.html << 'EOF'
<h1>功能文档</h1>

<h2>功能列表</h2>
<table>
  <tbody>
    <tr>
      <th>功能</th>
      <th>状态</th>
      <th>备注</th>
    </tr>
    <tr>
      <td>用户认证</td>
      <td>✅ 完成</td>
      <td>已上线</td>
    </tr>
    <tr>
      <td>权限管理</td>
      <td>🚧 开发中</td>
      <td>预计下周完成</td>
    </tr>
  </tbody>
</table>

<h2>代码示例</h2>
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">python</ac:parameter>
  <ac:plain-text-body><![CDATA[
def authenticate_user(username, password):
    """用户认证函数"""
    if validate_credentials(username, password):
        return generate_token(username)
    return None
]]></ac:plain-text-body>
</ac:structured-macro>
EOF

# 更新到 Wiki
python scripts/wiki_manager.py update \
  --url "https://wiki.*.com/pages/12345678" \
  --format html \
  --file content.html \
  --title "功能文档"
```

### 场景 3: 追加实施记录到现有页面

```bash
# 追加 HTML 格式的实施记录
python scripts/wiki_manager.py update \
  --page-id 12345678 \
  --format html \
  --append \
  --content "<h2>实施记录 - 2026-01-21</h2>
<ul>
  <li>✅ 完成需求分析</li>
  <li>✅ 已评审通过</li>
  <li>🚧 开始实施阶段</li>
</ul>

<ac:structured-macro ac:name=\"info\">
  <ac:rich-text-body>
    <p>下一步：进行单元测试</p>
  </ac:rich-text-body>
</ac:structured-macro>"
```

### 场景 4: 创建带提示框的文档

```bash
python scripts/wiki_manager.py update \
  --page-id 12345678 \
  --format html \
  --content "<h1>API 使用指南</h1>

<ac:structured-macro ac:name=\"warning\">
  <ac:rich-text-body>
    <p><strong>重要：</strong>使用前请先配置环境变量</p>
  </ac:rich-text-body>
</ac:structured-macro>

<h2>快速开始</h2>
<ac:structured-macro ac:name=\"code\">
  <ac:parameter ac:name=\"language\">bash</ac:parameter>
  <ac:plain-text-body><![CDATA[
export API_KEY=\"your-api-key\"
export API_SECRET=\"your-api-secret\"
]]></ac:plain-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name=\"tip\">
  <ac:rich-text-body>
    <p>API 密钥可以在设置页面获取</p>
  </ac:rich-text-body>
</ac:structured-macro>"
```

### 场景 5: 创建大型内容页面（分批添加）

```bash
# 方案 1: 手动指定分批大小
python scripts/wiki_manager.py create \
  --title "大型设计文档" \
  --space "~ht" \
  --format html \
  --file large_design.html \
  --chunk-size 1048576  # 1MB

# 方案 2: 从多个文件合并创建
cat part1.html part2.html part3.html > combined.html
python scripts/wiki_manager.py create \
  --title "合并文档" \
  --space "~ht" \
  --format html \
  --file combined.html \
  --chunk-size 524288  # 512KB

# 输出示例：
# 📦 内容大小 2097152 字节超过限制 1048576 字节，将分批创建...
# 📊 内容已分为 2 批
# 📝 创建页面（第 1/2 批，1048576 字节）...
# ✅ 页面已创建，ID: 12345678
# 📝 追加内容（第 2/2 批，1048576 字节）...
# ✅ 第 2 批已追加
# 🎉 所有内容已成功添加到页面
# ✅ 页面已成功创建（分 2 批添加内容，总大小 2097152 字节），ID: 12345678
```

### 场景 6: 批量处理多个页面

```bash
# 批量更新多个页面（HTML 格式）
for page_id in 12345678 87654321 11223344; do
  python scripts/wiki_manager.py update \
    --page-id "$page_id" \
    --format html \
    --file "docs/page_${page_id}.html"
done
```

## Python API 使用

除了 CLI 命令，也可以在 Python 代码中直接调用：

```python
import asyncio
from wiki_manager import WikiConfig, get_wiki_page_content, update_wiki_page_content, create_wiki_page, create_wiki_page_with_chunks

async def main():
    # 初始化配置（自动读取环境变量，包括默认空间和父页面）
    config = WikiConfig()

    # 查看配置的默认值
    print(f"默认空间: {config.default_space or '未配置'}")
    print(f"默认父页面: {config.default_parent_page_id or '未配置'}")

    # 创建新页面（使用默认空间）
    new_page = await create_wiki_page(
        config,
        title="新建页面",
        content="<h1>页面内容</h1><p>这是新建的页面</p>",
        space_key=config.default_space,  # 使用默认空间
        format="html",
        parent_page_id=config.default_parent_page_id  # 使用默认父页面
    )
    print(f"创建成功: {new_page['message']}")
    print(f"页面 URL: {new_page['url']}")

    # 创建大内容页面（自动分批）
    large_page = await create_wiki_page_with_chunks(
        config,
        title="大型文档",
        content="<h1>这是一个超大内容</h1>" + "<p>内容段落</p>" * 10000,
        space_key=config.default_space,
        format="html",
        parent_page_id=config.default_parent_page_id,
        chunk_size=1048576  # 1MB
    )
    print(f"创建成功: {large_page['message']}")
    if large_page.get('chunked'):
        print(f"分批数: {large_page['chunks']}")
        print(f"总大小: {large_page['total_size']} 字节")

    # 获取页面内容（HTML Storage Format）
    page = await get_wiki_page_content(
        config,
        page_id="12345678",
        format="storage"  # 推荐使用 storage 格式
    )
    print(f"标题: {page['title']}")
    print(f"内容: {page['content']}")

    # 更新页面（HTML 格式）
    html_content = """
    <h1>新标题</h1>
    <p>这是更新后的内容</p>
    <table>
      <tbody>
        <tr><th>列1</th><th>列2</th></tr>
        <tr><td>数据1</td><td>数据2</td></tr>
      </tbody>
    </table>
    """

    result = await update_wiki_page_content(
        config,
        page_id="12345678",
        content=html_content,
        format="html",  # 使用 HTML 格式
        append=False
    )
    print(f"更新成功: {result['message']}")

asyncio.run(main())
```

## Notes

- **格式推荐**: 推荐使用 HTML Storage Format 以获得最佳兼容性和格式控制
- **版本管理**: 脚本自动处理版本号递增，无需手动管理
- **冲突处理**: 如果页面在获取和更新之间被其他人修改，会返回 409 冲突错误
- **权限要求**: 更新操作需要用户具有相应页面的编辑权限
- **Markdown 支持**: 虽然支持 Markdown，但转换为 HTML 时可能会丢失部分格式
- **HTML 处理**: Confluence 使用 Storage Format（特殊的 HTML 格式）存储内容
- **URL 格式**: 支持两种常见的 Confluence URL 格式自动识别
- **特殊字符**: 在 HTML 中使用 `&lt;`、`&gt;`、`&amp;` 等转义字符
- **CDATA**: 代码块中的内容应使用 `<![CDATA[...]]>` 包裹以避免解析问题

## Error Handling

常见错误及解决方案：

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `未配置 WIKI_TOKEN` | 环境变量未设置 | 设置 `export WIKI_TOKEN="..."` |
| `401 认证失败` | Token 无效或过期 | 检查 Token 是否正确 |
| `403 权限不足` | 没有页面编辑权限 | 联系管理员授权 |
| `404 资源不存在` | 页面 ID 不存在 | 检查页面 ID 是否正确 |
| `409 版本冲突` | 页面被其他人修改 | 重新获取页面内容后再更新 |
| `HTML 格式错误` | HTML 标签不匹配或格式不正确 | 检查 HTML 标签是否闭合 |

## Script Details

### 脚本位置

- `scripts/wiki_manager.py` - 主脚本（独立可执行）

### 脚本特性

- **异步设计**: 使用 `asyncio` 和 `httpx` 实现异步 HTTP 请求
- **独立运行**: 无外部依赖，可直接在命令行使用
- **错误处理**: 完善的错误处理和友好的错误信息
- **格式支持**: HTML ↔ Markdown 自动转换
- **CLI + API**: 同时支持命令行和 Python API 调用

### 关键函数

- `extract_page_id(page_url)` - 从 URL 提取页面 ID
- `create_wiki_page(config, title, content, space_key, format, parent_page_id)` - 创建新页面
- `create_wiki_page_with_chunks(config, title, content, space_key, format, parent_page_id, chunk_size)` - 创建新页面（内容过长时自动分批）
- `get_wiki_page_content(config, page_id, format)` - 获取页面内容
- `update_wiki_page_content(config, page_id, content, title, format, append)` - 更新页面

## Best Practices

1. **使用 HTML 格式**: 推荐使用 Confluence HTML Storage Format 以获得最佳兼容性
2. **获取现有内容**: 使用追加模式前先获取页面现有内容
3. **使用 CDATA**: 代码块中的代码应使用 `<![CDATA[...]]>` 包裹
4. **版本控制**: 重要更新前先备份页面内容
5. **测试小改动**: 在测试页面上先测试 HTML 格式是否正确
6. **使用提示框**: 使用 Confluence 宏（如 info、warning）增强可读性
7. **表格格式**: 确保表格包含 `<tbody>` 标签以保证正确渲染
8. **处理大内容**: 内容超过 1MB 时建议使用 `--chunk-size` 参数分批创建，避免 API 超时
9. **UTF-8 安全**: 分批功能会自动确保不在 UTF-8 字符中间切分，保证内容完整性
10. **监控进度**: 分批创建时会显示详细进度信息，便于监控大文档创建过程
11. **配置默认值**: 为常用的空间和父页面配置环境变量，简化命令行操作：
    ```bash
    export WIKI_DEFAULT_SPACE="~ht"
    export WIKI_DEFAULT_PARENT_PAGE="217851921"
    ```
    这样创建页面时就无需每次都指定这些参数。
12. **批处理建议**: 对于批量创建多个页面的场景，可以写脚本循环调用 `create` 命令。
