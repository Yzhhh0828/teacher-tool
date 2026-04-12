from sqlalchemy.ext.asyncio import AsyncSession
from app.database import async_session_maker
from app.mcp.tools import MCPTools


def get_mcp_tools(db: AsyncSession, user_id: int) -> MCPTools:
    return MCPTools(db, user_id)
