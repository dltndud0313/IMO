"""
명세 §1-3 공통 응답 구조 헬퍼.
모든 라우터는 이 헬퍼로 응답을 감싸서 {success, data, error} 형태를 보장한다.
"""
from typing import Any, Optional


def success_response(data: Any = None) -> dict:
    return {"success": True, "data": data, "error": None}


def error_response(code: str, message: str) -> dict:
    return {
        "success": False,
        "data": None,
        "error": {"code": code, "message": message},
    }
