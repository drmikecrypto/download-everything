from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    cors_origins: str = "*"
    max_analyze_timeout: int = 60
    user_agent: str = (
        "Mozilla/5.0 (compatible; DownloadEverything/1.0; +https://github.com/drmikecrypto/download-everything)"
    )

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    class Config:
        env_file = ".env"


settings = Settings()
