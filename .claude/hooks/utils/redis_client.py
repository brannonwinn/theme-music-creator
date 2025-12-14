"""
Redis client for observability caching with graceful degradation.

Provides caching for:
- Project context (1hr TTL)
- Worktree/agent context (1hr TTL)
- Git context (30s TTL)
- Agent health (5min TTL)
- Session state (24hr TTL)
"""

import redis
from typing import Optional, Dict, Any
import json
import os


class RedisClient:
    """Redis client for observability caching with graceful degradation."""

    def __init__(self, redis_url: str = "redis://localhost:6380/0"):
        """
        Initialize Redis client.

        Args:
            redis_url: Redis connection URL (default: shared Supabase Redis on 6380/db0)
        """
        self.redis_url = redis_url
        self._client: Optional[redis.Redis] = None
        self._connect()

    def _connect(self):
        """Connect to Redis with error handling and graceful degradation."""
        try:
            self._client = redis.from_url(
                self.redis_url,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2
            )
            # Test connection
            self._client.ping()
        except Exception as e:
            print(f"Redis connection failed: {e}. Continuing without cache.")
            self._client = None

    def is_available(self) -> bool:
        """Check if Redis is available."""
        return self._client is not None

    def get_context(self, key: str) -> Optional[Dict[str, Any]]:
        """
        Get cached context from Redis.

        Args:
            key: Redis key

        Returns:
            Dict with cached data or None if cache miss or Redis unavailable
        """
        if not self._client:
            return None
        try:
            data = self._client.get(key)
            return json.loads(data) if data else None
        except Exception:
            return None

    def set_context(self, key: str, value: Dict[str, Any], ttl: int = 3600) -> bool:
        """
        Set cached context in Redis with TTL.

        Args:
            key: Redis key
            value: Dict to cache (will be JSON serialized)
            ttl: Time to live in seconds (default: 1 hour)

        Returns:
            True if successful, False otherwise
        """
        if not self._client:
            return False
        try:
            self._client.setex(key, ttl, json.dumps(value))
            return True
        except Exception:
            return False

    def get_git(self, project_name: str, worktree_name: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """
        Get cached git context.

        Args:
            project_name: Project identifier
            worktree_name: Worktree name (optional, for worktree-specific cache)

        Returns:
            Dict with git data or None
        """
        key = f"project:{project_name}"
        if worktree_name:
            key += f":worktree:{worktree_name}"
        key += ":git"
        return self.get_context(key)

    def set_git(
        self,
        project_name: str,
        git_data: Dict[str, Any],
        worktree_name: Optional[str] = None,
        ttl: int = 30
    ) -> bool:
        """
        Set cached git context with 30s TTL.

        Args:
            project_name: Project identifier
            git_data: Git status data
            worktree_name: Worktree name (optional)
            ttl: Time to live in seconds (default: 30s for fast updates)

        Returns:
            True if successful, False otherwise
        """
        key = f"project:{project_name}"
        if worktree_name:
            key += f":worktree:{worktree_name}"
        key += ":git"
        return self.set_context(key, git_data, ttl)

    def get_health(self, project_name: str, agent_color: str) -> Optional[Dict[str, Any]]:
        """
        Get cached agent health.

        Args:
            project_name: Project identifier
            agent_color: Agent color identifier

        Returns:
            Dict with health data or None
        """
        key = f"project:{project_name}:agent:{agent_color}:health"
        return self.get_context(key)

    def set_health(
        self,
        project_name: str,
        agent_color: str,
        health_data: Dict[str, Any],
        ttl: int = 300
    ) -> bool:
        """
        Set cached agent health with 5min TTL.

        Args:
            project_name: Project identifier
            agent_color: Agent color identifier
            health_data: Health metrics
            ttl: Time to live in seconds (default: 5 minutes)

        Returns:
            True if successful, False otherwise
        """
        key = f"project:{project_name}:agent:{agent_color}:health"
        return self.set_context(key, health_data, ttl)

    def get_session_state(self, project_name: str, session_id: str) -> Optional[Dict[str, Any]]:
        """Get cached session state."""
        key = f"project:{project_name}:session:{session_id}:state"
        return self.get_context(key)

    def set_session_state(
        self,
        project_name: str,
        session_id: str,
        state_data: Dict[str, Any],
        ttl: int = 86400
    ) -> bool:
        """Set cached session state with 24hr TTL."""
        key = f"project:{project_name}:session:{session_id}:state"
        return self.set_context(key, state_data, ttl)

    def add_to_set(self, key: str, value: str, ttl: Optional[int] = None) -> bool:
        """
        Add value to a Redis set.

        Useful for tracking active sessions, active agents, etc.

        Args:
            key: Redis key for the set
            value: Value to add to set
            ttl: Optional TTL for the key

        Returns:
            True if successful, False otherwise
        """
        if not self._client:
            return False
        try:
            self._client.sadd(key, value)
            if ttl:
                self._client.expire(key, ttl)
            return True
        except Exception:
            return False

    def get_set_members(self, key: str) -> set:
        """
        Get all members of a Redis set.

        Args:
            key: Redis key for the set

        Returns:
            Set of members or empty set
        """
        if not self._client:
            return set()
        try:
            return self._client.smembers(key)
        except Exception:
            return set()
