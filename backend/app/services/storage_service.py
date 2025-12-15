import os

from supabase import create_client, Client


SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_BUCKET_THEMES = os.getenv("SUPABASE_STORAGE_BUCKET_THEMES", "themes")
SUPABASE_BUCKET_VARIATIONS = os.getenv("SUPABASE_STORAGE_BUCKET_VARIATIONS", "variations")


class SupabaseStorageService:
    """Service for uploading files to Supabase Storage."""

    def __init__(
        self,
        url: str = SUPABASE_URL,
        key: str = SUPABASE_SERVICE_ROLE_KEY,
        bucket_themes: str = SUPABASE_BUCKET_THEMES,
        bucket_variations: str = SUPABASE_BUCKET_VARIATIONS,
    ):
        if not url or not key:
            raise RuntimeError("Supabase URL and SERVICE_ROLE_KEY must be set")
        self.client: Client = create_client(url, key)
        self.bucket_themes = bucket_themes
        self.bucket_variations = bucket_variations

    def upload_theme_file(self, theme_id: str, filename: str, data: bytes) -> str:
        """Upload a file to the themes bucket and return its public URL."""
        path = f"{theme_id}/{filename}"
        self.client.storage.from_(self.bucket_themes).upload(
            path, data, {"upsert": "true"}
        )
        return self.client.storage.from_(self.bucket_themes).get_public_url(path)

    def upload_variation_file(
        self, variation_id: str, filename: str, data: bytes
    ) -> str:
        """Upload a file to the variations bucket and return its public URL."""
        path = f"{variation_id}/{filename}"
        self.client.storage.from_(self.bucket_variations).upload(
            path, data, {"upsert": "true"}
        )
        return self.client.storage.from_(self.bucket_variations).get_public_url(path)


def get_storage_service() -> SupabaseStorageService:
    """Factory function to get a SupabaseStorageService instance."""
    return SupabaseStorageService()
