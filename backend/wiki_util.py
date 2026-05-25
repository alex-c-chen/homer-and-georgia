import httpx

WIKIPEDIA_API = "https://en.wikipedia.org/api/rest_v1/page/summary/{title}"


def fetch_wikipedia_summary(topic_name: str) -> dict:
    """Fetch Wikipedia page summary and thumbnail for a topic.

    :param topic_name: Topic display name (used as Wikipedia search title).
    :returns: Dict with keys: extract (str), thumbnail_url (str|None), page_url (str).
    :raises httpx.HTTPError: if the Wikipedia API is unreachable.
    """
    url = WIKIPEDIA_API.format(title=topic_name.replace(" ", "_"))
    headers = {"User-Agent": "homer-and-georgia/1.0 (alexchenchen1@gmail.com)"}
    resp = httpx.get(url, timeout=10, follow_redirects=True, headers=headers)
    resp.raise_for_status()
    data = resp.json()
    return {
        "extract": data.get("extract", ""),
        "thumbnail_url": data.get("thumbnail", {}).get("source"),
        "page_url": data.get("content_urls", {}).get("desktop", {}).get("page", ""),
    }
