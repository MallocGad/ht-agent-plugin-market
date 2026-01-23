#!/usr/bin/env python3
"""
Confluence Wiki Manager - 完整的 Wiki 页面管理工具

功能：
- 获取 Wiki 页面内容（支持 Markdown/HTML 格式）
- 更新 Wiki 页面内容和标题
- 追加内容到现有页面
- 创建新页面（支持大内容自动分批）
- 从 URL 自动提取页面 ID

环境变量配置：
- WIKI_BASE_URL: Confluence 基础 URL（默认: https://wiki.*.com）
- WIKI_TOKEN: Confluence API Token（必需）
- WIKI_DEFAULT_SPACE: 默认空间 key（可选，例如: ~ht）
- WIKI_DEFAULT_PARENT_PAGE: 默认父页面 ID（可选，例如: 217851921）
"""

import os
import re
import sys
import json
import asyncio
import argparse
from typing import Optional
from markdownify import markdownify as md

try:
    import httpx
except ImportError:
    print("错误：需要安装 httpx 库")
    print("运行: pip install httpx")
    sys.exit(1)

try:
    import markdown
except ImportError:
    markdown = None


# ============================================================================
# 配置管理
# ============================================================================

class WikiConfig:
    """Wiki 配置管理"""

    def __init__(self):
        self.base_url = os.getenv("WIKI_BASE_URL", "https://wiki.*.com")
        self.token = os.getenv("WIKI_TOKEN", "")
        self.default_space = os.getenv("WIKI_DEFAULT_SPACE", "")
        self.default_parent_page_id = os.getenv("WIKI_DEFAULT_PARENT_PAGE", "")

        if not self.token.strip():
            raise ValueError(
                "未配置 WIKI_TOKEN 环境变量\n"
                "请设置: export WIKI_TOKEN='your-token-here'"
            )

    def get_auth_headers(self) -> dict:
        """生成认证请求头"""
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }


# ============================================================================
# HTTP 客户端
# ============================================================================

async def fetch_json(
    url: str,
    headers: dict,
    params: Optional[dict] = None,
    timeout: float = 30.0
) -> dict:
    """通用 HTTP GET 请求"""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                url,
                headers=headers,
                params=params,
                timeout=timeout
            )
            response.raise_for_status()
            return {"success": True, "data": response.json()}

        except httpx.HTTPStatusError as e:
            status = e.response.status_code
            error_map = {
                401: "认证失败，请检查 Token",
                403: "权限不足",
                404: "资源不存在",
                429: "请求过于频繁，请稍后重试"
            }
            return {
                "success": False,
                "error": error_map.get(status, f"HTTP {status} 错误"),
                "status_code": status
            }

        except Exception as e:
            return {"success": False, "error": str(e)}


async def put_json(
    url: str,
    headers: dict,
    data: dict,
    timeout: float = 30.0
) -> dict:
    """通用 HTTP PUT 请求"""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.put(
                url,
                headers=headers,
                json=data,
                timeout=timeout
            )
            response.raise_for_status()
            return {"success": True, "data": response.json()}

        except httpx.HTTPStatusError as e:
            status = e.response.status_code
            error_map = {
                401: "认证失败，请检查 Token",
                403: "权限不足，请检查是否有编辑权限",
                404: "资源不存在",
                409: "版本冲突，页面已被其他人修改",
                429: "请求过于频繁，请稍后重试"
            }
            return {
                "success": False,
                "error": error_map.get(status, f"HTTP {status} 错误"),
                "status_code": status
            }

        except Exception as e:
            return {"success": False, "error": str(e)}


async def post_json(
    url: str,
    headers: dict,
    data: dict,
    timeout: float = 30.0
) -> dict:
    """通用 HTTP POST 请求"""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                headers=headers,
                json=data,
                timeout=timeout
            )
            response.raise_for_status()
            return {"success": True, "data": response.json()}

        except httpx.HTTPStatusError as e:
            status = e.response.status_code
            error_map = {
                401: "认证失败，请检查 Token",
                403: "权限不足，请检查是否有创建页面权限",
                404: "资源不存在",
                400: "请求参数错误",
                429: "请求过于频繁，请稍后重试"
            }
            return {
                "success": False,
                "error": error_map.get(status, f"HTTP {status} 错误"),
                "status_code": status
            }

        except Exception as e:
            return {"success": False, "error": str(e)}


# ============================================================================
# 核心功能
# ============================================================================

def extract_page_id(page_url: str) -> str:
    """从 URL 提取页面 ID

    支持的 URL 格式：
    - https://wiki.*.com/pages/12345678
    - https://wiki.*.com/pages/viewpage.action?pageId=12345678
    """
    # 格式1: /pages/12345678
    match = re.search(r'/pages/(\d+)', page_url)
    if match:
        return match.group(1)

    # 格式2: pageId=12345678
    match = re.search(r'pageId=(\d+)', page_url)
    if match:
        return match.group(1)

    raise ValueError(f"无法从 URL 提取页面 ID: {page_url}")


async def get_wiki_page_content(
    config: WikiConfig,
    page_id: Optional[str] = None,
    page_url: Optional[str] = None,
    format: str = "markdown"
) -> dict:
    """获取 Wiki 页面内容

    Args:
        config: Wiki 配置
        page_id: 页面 ID
        page_url: 页面 URL（如果提供则自动提取 page_id）
        format: 输出格式，'markdown'（默认）、'storage'（HTML）或 'view'

    Returns:
        包含页面信息的字典
    """
    # 处理 page_url
    if page_url and not page_id:
        page_id = extract_page_id(page_url)

    if not page_id:
        raise ValueError("必须提供 page_id 或 page_url")

    url = f"{config.base_url}/rest/api/content/{page_id}"
    headers = config.get_auth_headers()
    params = {
        "expand": "body.storage,body.view,version,space,metadata.labels,children.attachment"
    }

    result = await fetch_json(url, headers, params)

    if not result["success"]:
        raise RuntimeError(result["error"])

    # 解析数据
    data = result["data"]

    # 选择内容格式
    if format == "storage":
        content = data.get("body", {}).get("storage", {}).get("value", "")
    elif format == "view":
        content = data.get("body", {}).get("view", {}).get("value", "")
    else:  # markdown
        html_content = data.get("body", {}).get("storage", {}).get("value", "")
        content = md(html_content, heading_style="ATX")

    parsed = {
        "id": data["id"],
        "title": data["title"],
        "url": f"{config.base_url}/pages/viewpage.action?pageId={data['id']}",
        "space": data.get("space", {}).get("key", ""),
        "content": content,
        "version": data.get("version", {}).get("number", 0),
        "last_updated": data.get("version", {}).get("when", ""),
        "last_updated_by": data.get("version", {}).get("by", {}).get("displayName", ""),
        "labels": [
            label["name"]
            for label in data.get("metadata", {}).get("labels", {}).get("results", [])
        ]
    }

    # 附件
    attachments = data.get("children", {}).get("attachment", {}).get("results", [])
    parsed["attachments"] = [
        {
            "filename": a.get("title", ""),
            "size": a.get("extensions", {}).get("fileSize", 0),
            "url": f"{config.base_url}{a.get('_links', {}).get('download', '')}"
        }
        for a in attachments
    ]

    return parsed


async def update_wiki_page_content(
    config: WikiConfig,
    page_id: str,
    content: Optional[str] = None,
    title: Optional[str] = None,
    format: str = "markdown",
    append: bool = False
) -> dict:
    """更新 Wiki 页面内容

    Args:
        config: Wiki 配置
        page_id: 页面 ID
        content: 新内容（如果为空则不修改内容）
        title: 新标题（如果为空则不修改标题）
        format: 内容格式，'markdown'（默认）或 'html'
        append: 是否追加内容（True=追加到末尾，False=覆盖）

    Returns:
        更新后的页面信息
    """
    if not content and not title:
        raise ValueError("至少需要提供 content 或 title")

    # 1. 获取当前页面信息（需要版本号）
    current_page = await get_wiki_page_content(config, page_id=page_id, format="storage")
    current_version = current_page["version"]
    current_title = current_page["title"]
    current_content_html = current_page["content"]

    # 2. 处理新内容
    if content:
        # 转换 Markdown 为 HTML（如果需要）
        if format == "markdown":
            if markdown is None:
                raise RuntimeError("需要安装 markdown 库: pip install markdown")
            new_content_html = markdown.markdown(content, extensions=['extra', 'nl2br'])
        else:  # html
            new_content_html = content

        # 追加模式：在原有内容后添加
        if append:
            final_content_html = current_content_html + "\n" + new_content_html
        else:
            final_content_html = new_content_html
    else:
        # 不修改内容
        final_content_html = current_content_html

    # 3. 处理标题
    final_title = title if title else current_title

    # 4. 构造更新请求
    url = f"{config.base_url}/rest/api/content/{page_id}"
    headers = config.get_auth_headers()

    update_data = {
        "version": {"number": current_version + 1},
        "title": final_title,
        "type": "page",
        "body": {
            "storage": {
                "value": final_content_html,
                "representation": "storage"
            }
        }
    }

    # 5. 发送 PUT 请求
    result = await put_json(url, headers, update_data)

    if not result["success"]:
        raise RuntimeError(f"更新 Wiki 页面失败: {result['error']}")

    # 6. 解析返回数据
    data = result["data"]
    return {
        "id": data["id"],
        "title": data["title"],
        "url": f"{config.base_url}/pages/viewpage.action?pageId={data['id']}",
        "version": data.get("version", {}).get("number", 0),
        "last_updated": data.get("version", {}).get("when", ""),
        "last_updated_by": data.get("version", {}).get("by", {}).get("displayName", ""),
        "message": f"页面已成功更新到版本 {data.get('version', {}).get('number', 0)}"
    }


async def create_wiki_page(
    config: WikiConfig,
    title: str,
    content: str,
    space_key: str,
    format: str = "html",
    parent_page_id: Optional[str] = None
) -> dict:
    """创建新的 Wiki 页面

    Args:
        config: Wiki 配置
        title: 页面标题（必需）
        content: 页面内容（必需）
        space_key: 空间 key（例如: "~ht", "SPACE" 等）
        format: 内容格式，'html'（默认，推荐）或 'markdown'
        parent_page_id: 父页面 ID（如果为空则创建顶级页面）

    Returns:
        新创建的页面信息
    """
    if not title:
        raise ValueError("必须提供页面标题")

    if not content:
        raise ValueError("必须提供页面内容")

    if not space_key:
        raise ValueError("必须提供空间 key")

    # 1. 处理内容格式
    if format == "markdown":
        if markdown is None:
            raise RuntimeError("需要安装 markdown 库: pip install markdown")
        content_html = markdown.markdown(content, extensions=['extra', 'nl2br'])
    else:  # html
        content_html = content

    # 2. 构造创建页面请求
    url = f"{config.base_url}/rest/api/content"
    headers = config.get_auth_headers()

    create_data = {
        "type": "page",
        "title": title,
        "space": {"key": space_key},
        "status": "current",
        "body": {
            "storage": {
                "value": content_html,
                "representation": "storage"
            }
        }
    }

    # 3. 如果指定了父页面，添加到 ancestors
    if parent_page_id:
        create_data["ancestors"] = [{"id": parent_page_id}]

    # 4. 发送 POST 请求
    result = await post_json(url, headers, create_data)

    if not result["success"]:
        raise RuntimeError(f"创建 Wiki 页面失败: {result['error']}")

    # 5. 解析返回数据
    data = result["data"]
    return {
        "id": data["id"],
        "title": data["title"],
        "url": f"{config.base_url}/pages/viewpage.action?pageId={data['id']}",
        "space": data.get("space", {}).get("key", ""),
        "version": data.get("version", {}).get("number", 0),
        "created": data.get("version", {}).get("when", ""),
        "created_by": data.get("version", {}).get("by", {}).get("displayName", ""),
        "message": f"页面已成功创建，ID: {data['id']}"
    }


async def create_wiki_page_with_chunks(
    config: WikiConfig,
    title: str,
    content: str,
    space_key: str,
    format: str = "html",
    parent_page_id: Optional[str] = None,
    chunk_size: int = 1024 * 1024  # 默认 1MB
) -> dict:
    """创建 Wiki 页面，如果内容过长则分批追加

    Args:
        config: Wiki 配置
        title: 页面标题（必需）
        content: 页面内容（必需）
        space_key: 空间 key（例如: "~ht", "SPACE" 等）
        format: 内容格式，'html'（默认，推荐）或 'markdown'
        parent_page_id: 父页面 ID（如果为空则创建顶级页面）
        chunk_size: 每批内容的最大字节数（默认: 1MB）

    Returns:
        创建的页面信息，包含分批统计
    """
    if not title:
        raise ValueError("必须提供页面标题")

    if not content:
        raise ValueError("必须提供页面内容")

    if not space_key:
        raise ValueError("必须提供空间 key")

    # 1. 处理内容格式
    if format == "markdown":
        if markdown is None:
            raise RuntimeError("需要安装 markdown 库: pip install markdown")
        content_html = markdown.markdown(content, extensions=['extra', 'nl2br'])
    else:  # html
        content_html = content

    # 2. 计算内容大小
    content_bytes = content_html.encode('utf-8')
    total_size = len(content_bytes)

    # 3. 如果内容不超过限制，直接创建
    if total_size <= chunk_size:
        result = await create_wiki_page(
            config=config,
            title=title,
            content=content_html,
            space_key=space_key,
            format="html",  # 已经转换过了
            parent_page_id=parent_page_id
        )
        result["chunked"] = False
        result["total_size"] = total_size
        result["chunks"] = 1
        return result

    # 4. 内容过长，需要分批处理
    print(f"📦 内容大小 {total_size} 字节超过限制 {chunk_size} 字节，将分批创建...")

    # 5. 将内容分割成多个批次（智能切分，保证 HTML 完整性）
    chunks = []
    offset = 0
    while offset < total_size:
        chunk_end = min(offset + chunk_size, total_size)
        chunk_bytes = content_bytes[offset:chunk_end]

        # 首先尝试 UTF-8 解码
        chunk_text = None
        try:
            chunk_text = chunk_bytes.decode('utf-8')
        except UnicodeDecodeError:
            # 回退到前一个完整字符
            while chunk_end > offset:
                chunk_end -= 1
                chunk_bytes = content_bytes[offset:chunk_end]
                try:
                    chunk_text = chunk_bytes.decode('utf-8')
                    break
                except UnicodeDecodeError:
                    continue

        if chunk_text is None:
            raise RuntimeError("无法正确分割 UTF-8 内容")

        # 如果不是最后一块，尝试在 HTML 标签边界处切分（优化切分点）
        if chunk_end < total_size:
            # 尝试找到最近的闭合标签作为切分点（</p>, </li>, </td> 等）
            # 按优先级查找：</p> > </li> > </td> > </div>
            for tag in ['</p>', '</li>', '</td>', '</div>']:
                last_tag_pos = chunk_text.rfind(tag)
                if last_tag_pos > 0 and last_tag_pos > len(chunk_text) // 2:  # 至少在中点之后
                    # 从标签后面开始下一块
                    chunk_text = chunk_text[:last_tag_pos + len(tag)]
                    chunk_end = offset + len(chunk_text.encode('utf-8'))
                    break

        chunks.append(chunk_text)
        offset = chunk_end

    print(f"📊 内容已分为 {len(chunks)} 批")

    # 6. 创建页面（使用第一批内容）
    print(f"📝 创建页面（第 1/{len(chunks)} 批，{len(chunks[0].encode('utf-8'))} 字节）...")
    result = await create_wiki_page(
        config=config,
        title=title,
        content=chunks[0],
        space_key=space_key,
        format="html",
        parent_page_id=parent_page_id
    )

    page_id = result["id"]
    print(f"✅ 页面已创建，ID: {page_id}")

    # 7. 追加剩余内容
    for i, chunk in enumerate(chunks[1:], start=2):
        print(f"📝 追加内容（第 {i}/{len(chunks)} 批，{len(chunk.encode('utf-8'))} 字节）...")
        await update_wiki_page_content(
            config=config,
            page_id=page_id,
            content=chunk,
            format="html",
            append=True
        )
        print(f"✅ 第 {i} 批已追加")

    # 8. 返回最终结果
    print(f"🎉 所有内容已成功添加到页面")
    result["chunked"] = True
    result["total_size"] = total_size
    result["chunks"] = len(chunks)
    result["message"] = f"页面已成功创建（分 {len(chunks)} 批添加内容，总大小 {total_size} 字节），ID: {page_id}"

    return result


# ============================================================================
# CLI 接口
# ============================================================================

async def cmd_get(args):
    """获取页面内容命令"""
    config = WikiConfig()

    try:
        result = await get_wiki_page_content(
            config,
            page_id=args.page_id,
            page_url=args.url,
            format=args.format
        )

        if args.output:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(result["content"])
            print(f"✅ 内容已保存到: {args.output}")

        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            print(f"📄 标题: {result['title']}")
            print(f"🔗 URL: {result['url']}")
            print(f"📁 空间: {result['space']}")
            print(f"📌 版本: {result['version']}")
            print(f"👤 最后更新: {result['last_updated_by']} ({result['last_updated']})")
            if result['labels']:
                print(f"🏷️  标签: {', '.join(result['labels'])}")
            if result['attachments']:
                print(f"📎 附件数: {len(result['attachments'])}")
            if not args.output:
                print(f"\n--- 内容 ---\n{result['content']}")

    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)


async def cmd_update(args):
    """更新页面内容命令"""
    config = WikiConfig()

    try:
        # 处理 page_id
        page_id = args.page_id
        if args.url and not page_id:
            page_id = extract_page_id(args.url)

        if not page_id:
            raise ValueError("必须提供 --page-id 或 --url")

        # 读取内容
        content = None
        if args.content:
            content = args.content
        elif args.file:
            with open(args.file, 'r', encoding='utf-8') as f:
                content = f.read()

        # 执行更新
        result = await update_wiki_page_content(
            config,
            page_id=page_id,
            content=content,
            title=args.title,
            format=args.format,
            append=args.append
        )

        print(f"✅ {result['message']}")
        print(f"📄 标题: {result['title']}")
        print(f"🔗 URL: {result['url']}")
        print(f"📌 版本: {result['version']}")
        print(f"👤 更新者: {result['last_updated_by']}")

    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)


async def cmd_create(args):
    """创建页面命令"""
    config = WikiConfig()

    try:
        # 读取内容
        content = None
        if args.content:
            content = args.content
        elif args.file:
            with open(args.file, 'r', encoding='utf-8') as f:
                content = f.read()
        else:
            raise ValueError("必须提供 --content 或 --file")

        # 获取空间（优先使用命令行参数，其次使用默认值）
        space_key = args.space if args.space else config.default_space
        if not space_key:
            raise ValueError("必须提供 --space 或设置 WIKI_DEFAULT_SPACE 环境变量")

        # 获取父页面（优先使用命令行参数，其次使用默认值）
        parent_page_id = args.parent if args.parent else config.default_parent_page_id
        parent_page_id = parent_page_id if parent_page_id else None

        # 执行创建（如果指定了 chunk_size 则使用分批创建）
        if args.chunk_size:
            result = await create_wiki_page_with_chunks(
                config,
                title=args.title,
                content=content,
                space_key=space_key,
                format=args.format,
                parent_page_id=parent_page_id,
                chunk_size=args.chunk_size
            )
        else:
            result = await create_wiki_page(
                config,
                title=args.title,
                content=content,
                space_key=space_key,
                format=args.format,
                parent_page_id=parent_page_id
            )

        print(f"✅ {result['message']}")
        print(f"📄 标题: {result['title']}")
        print(f"🔗 URL: {result['url']}")
        print(f"📁 空间: {result['space']}")
        print(f"📌 版本: {result['version']}")
        print(f"👤 创建者: {result['created_by']}")

        # 显示分批信息
        if result.get('chunked'):
            print(f"📦 分批创建: {result['chunks']} 批，总大小: {result['total_size']} 字节")

    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)


async def cmd_extract_id(args):
    """提取页面 ID 命令"""
    try:
        page_id = extract_page_id(args.url)
        print(page_id)
    except Exception as e:
        print(f"❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="Confluence Wiki Manager - Wiki 页面管理工具",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = parser.add_subparsers(dest='command', help='可用命令')

    # get 命令
    get_parser = subparsers.add_parser('get', help='获取页面内容')
    get_parser.add_argument('--page-id', help='页面 ID')
    get_parser.add_argument('--url', help='页面 URL')
    get_parser.add_argument('--format', choices=['markdown', 'storage', 'view'],
                           default='markdown', help='输出格式（默认: markdown）')
    get_parser.add_argument('--output', '-o', help='保存内容到文件')
    get_parser.add_argument('--json', action='store_true', help='输出 JSON 格式')

    # update 命令
    update_parser = subparsers.add_parser('update', help='更新页面内容')
    update_parser.add_argument('--page-id', help='页面 ID')
    update_parser.add_argument('--url', help='页面 URL')
    update_parser.add_argument('--content', '-c', help='新内容（直接提供文本）')
    update_parser.add_argument('--file', '-f', help='新内容（从文件读取）')
    update_parser.add_argument('--title', '-t', help='新标题')
    update_parser.add_argument('--format', choices=['markdown', 'html'],
                              default='markdown', help='内容格式（默认: markdown）')
    update_parser.add_argument('--append', '-a', action='store_true',
                              help='追加内容（不覆盖原有内容）')

    # create 命令
    create_parser = subparsers.add_parser('create', help='创建新页面')
    create_parser.add_argument('--title', '-t', required=True, help='页面标题（必需）')
    create_parser.add_argument('--content', '-c', help='页面内容（直接提供文本）')
    create_parser.add_argument('--file', '-f', help='页面内容（从文件读取）')
    create_parser.add_argument('--space', '-s', help='空间 key，例如: ~ht, SPACE（如果未指定则使用 WIKI_DEFAULT_SPACE）')
    create_parser.add_argument('--parent', '-p', help='父页面 ID（如果未指定则使用 WIKI_DEFAULT_PARENT_PAGE）')
    create_parser.add_argument('--format', choices=['html', 'markdown'],
                              default='html', help='内容格式（默认: html）')
    create_parser.add_argument('--chunk-size', type=int, help='当内容超过此字节数时分批创建（如: 1048576 表示 1MB）')


    # extract-id 命令
    extract_parser = subparsers.add_parser('extract-id', help='从 URL 提取页面 ID')
    extract_parser.add_argument('url', help='页面 URL')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # 执行命令
    if args.command == 'get':
        asyncio.run(cmd_get(args))
    elif args.command == 'update':
        asyncio.run(cmd_update(args))
    elif args.command == 'create':
        asyncio.run(cmd_create(args))
    elif args.command == 'extract-id':
        asyncio.run(cmd_extract_id(args))


if __name__ == '__main__':
    main()
