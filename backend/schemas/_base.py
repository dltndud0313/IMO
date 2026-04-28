"""
모든 응답/요청 스키마의 공통 베이스.

- alias_generator=to_camel: 내부 snake_case 필드를 camelCase 로 직렬화/역직렬화
- populate_by_name=True: 코드 안에서는 snake_case 로 그대로 접근 가능
- from_attributes=True: ORM 객체에서 바로 변환 가능
"""
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )
