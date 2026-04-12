"""
MCP Server runner for standalone mode.
Can be used to run MCP server separately for Claude Desktop integration.
"""
from mcp.server.fastmcp import FastMCP
from app.database import async_session_maker
from app.mcp.tools import MCPTools

mcp = FastMCP("TeacherTool")


@mcp.tool()
async def get_students(class_id: int, user_id: int) -> list:
    """Get all students in a class"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.get_students(class_id)


@mcp.tool()
async def add_student(
    class_id: int,
    name: str,
    gender: str,
    user_id: int,
    phone: str = None,
    parent_phone: str = None,
) -> dict:
    """Add a new student"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.add_student(class_id, name, gender, phone, parent_phone)


@mcp.tool()
async def update_student(student_id: int, user_id: int, **fields) -> dict:
    """Update student information"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.update_student(student_id, **fields)


@mcp.tool()
async def delete_student(student_id: int, user_id: int) -> dict:
    """Delete a student"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.delete_student(student_id)


@mcp.tool()
async def get_grades(exam_id: int, user_id: int) -> list:
    """Get grades for an exam"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.get_grades(exam_id)


@mcp.tool()
async def add_grade(
    exam_id: int,
    student_id: int,
    subject: str,
    score: float,
    user_id: int,
) -> dict:
    """Add or update a grade"""
    async with async_session_maker() as db:
        tools = MCPTools(db, user_id)
        return await tools.add_grade(exam_id, student_id, subject, score)


if __name__ == "__main__":
    mcp.run()
