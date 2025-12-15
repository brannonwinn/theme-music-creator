import requests
from pydantic import HttpUrl


def post_callback(url: HttpUrl, event_type: str, payload: dict) -> None:
    """Send a webhook callback to the specified URL.

    Args:
        url: The callback URL to POST to
        event_type: The type of event (e.g., "theme.structure.completed")
        payload: The data to send in the callback
    """
    try:
        requests.post(
            str(url),
            json={"event_type": event_type, "data": payload},
            timeout=10,
        )
    except Exception as e:
        print(f"Callback to {url} failed: {e}")
