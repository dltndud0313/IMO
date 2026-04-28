"""
도메인 레벨 에러. 명세 §4-2 에러 코드 표를 따른다.

라우터에서 raise APIException(code, message, status_code) 하면
main.py의 글로벌 핸들러가 명세 형식 {success:false, error:{code,message}} 로 변환한다.
"""


class APIException(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


# 명세 §4-2 에 정의된 표준 에러를 빠르게 던지기 위한 단축 헬퍼들
class InvalidRequest(APIException):
    def __init__(self, message: str = "Invalid request"):
        super().__init__("INVALID_REQUEST", message, 400)


class ValidationError(APIException):
    def __init__(self, message: str = "Validation failed"):
        super().__init__("VALIDATION_ERROR", message, 400)


class Unauthorized(APIException):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__("UNAUTHORIZED", message, 401)


class TokenExpired(APIException):
    def __init__(self, message: str = "Token expired"):
        super().__init__("TOKEN_EXPIRED", message, 401)


class Forbidden(APIException):
    def __init__(self, message: str = "Forbidden"):
        super().__init__("FORBIDDEN", message, 403)


class SessionNotFound(APIException):
    def __init__(self, message: str = "Session not found"):
        super().__init__("SESSION_NOT_FOUND", message, 404)


class UserNotFound(APIException):
    def __init__(self, message: str = "User not found"):
        super().__init__("USER_NOT_FOUND", message, 404)


class DuplicateEmail(APIException):
    def __init__(self, message: str = "Email already exists"):
        super().__init__("DUPLICATE_EMAIL", message, 409)


class InternalError(APIException):
    def __init__(self, message: str = "Internal server error"):
        super().__init__("INTERNAL_ERROR", message, 500)
