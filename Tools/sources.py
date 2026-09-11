"""Shared access to the external data sources the catalogue tooling reads.

One definition of each endpoint, licence code and request convention, so the two scripts
cannot drift apart on what "an acceptable licence" or "the taxa endpoint" means.
"""

from __future__ import annotations

import json
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterator
from enum import StrEnum
from pathlib import Path
from typing import Any


def _ssl_context() -> ssl.SSLContext:
    """A context that trusts real certificates on every Python on this machine.

    Homebrew Python ships without the macOS trust store wired up, so a stock
    `urlopen` fails with CERTIFICATE_VERIFY_FAILED; the system Python happens to work.
    certifi fixes it uniformly. Verification is never disabled — an unverified fetch
    into a safety-critical dataset is not a shortcut worth taking.
    """
    try:
        import certifi
    except ImportError:
        return ssl.create_default_context()
    return ssl.create_default_context(cafile=certifi.where())


SSL_CONTEXT = _ssl_context()
USER_AGENT = "ForageNZ/1.0 (catalogue tooling; contact via repo)"
REQUEST_TIMEOUT = 30
#: Courtesy pause between calls — these are free public APIs.
COURTESY_DELAY = 0.3


class Licence(StrEnum):
    """Photo licences permissive enough to ship in an app.

    iNaturalist's default is CC BY-NC, which bars commercial use; neither member here
    does, so filtering to these keeps the app's options open.
    """

    CC0 = "cc0"
    CC_BY = "cc-by"

    @classmethod
    def query_value(cls) -> str:
        """The comma-separated form iNaturalist's `photo_license` filter expects."""
        return ",".join(str(licence) for licence in cls)


class Source(StrEnum):
    NZOR_SEARCH = "https://data.nzor.org.nz/names/search"
    INAT_TAXA = "https://api.inaturalist.org/v1/taxa"
    INAT_OBSERVATIONS = "https://api.inaturalist.org/v1/observations"
    INAT_HISTOGRAM = "https://api.inaturalist.org/v1/observations/histogram"


#: iNaturalist's place id for New Zealand. Establishment means and seasonality are both
#: place-scoped — a species introduced here may be native somewhere else.
NEW_ZEALAND_PLACE_ID = 6803


class SourceError(Exception):
    """A source could not be reached or returned something unusable."""


def get_json(url: Source | str, params: dict[str, object]) -> dict[str, Any]:
    request = urllib.request.Request(
        f"{url}?{urllib.parse.urlencode(params)}",
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(
            request, timeout=REQUEST_TIMEOUT, context=SSL_CONTEXT
        ) as response:
            payload: dict[str, Any] = json.load(response)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise SourceError(str(error)) from error
    return payload


def results_of(url: Source | str, params: dict[str, object]) -> list[dict[str, Any]]:
    """The `results` array, or empty. Raises `SourceError` if the call fails."""
    payload = get_json(url, params)
    results = payload.get("results")
    return results if isinstance(results, list) else []


def licensed_photos(
    observations: list[dict[str, Any]],
    directory: Path,
    species_id: str,
    wanted: int,
    size: str,
    downloader: Callable[[str, Path], bool] | None = None,
) -> Iterator[tuple[Path, Licence, dict[str, Any], dict[str, Any]]]:
    """Download up to `wanted` acceptably licensed photos from iNaturalist observations.

    One loop for both the catalogue stager and the evaluation fetcher, so they cannot drift
    on what counts as licensed or how a photo URL is rewritten. Yields (path, licence, photo,
    observation) for each file written; skips photos without an acceptable licence and reports
    failed downloads to stderr.
    """
    fetch = downloader or download
    count = 0
    for observation in observations:
        for photo in observation.get("photos") or []:
            if count >= wanted:
                return
            try:
                licence = Licence(photo.get("license_code"))
            except ValueError:
                continue
            # `square.` is a thumbnail; the caller picks the size it needs.
            url = str(photo.get("url") or "").replace("square.", f"{size}.")
            if not url:
                continue
            path = directory / f"{species_id}-{count + 1}.jpg"
            if not fetch(url, path):
                print(f"    download failed: {url}", file=sys.stderr)
                continue
            count += 1
            yield path, licence, photo, observation
            time.sleep(COURTESY_DELAY)


def download(url: str, destination: Path) -> bool:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(
            request, timeout=REQUEST_TIMEOUT, context=SSL_CONTEXT
        ) as response:
            destination.write_bytes(response.read())
    except (urllib.error.URLError, TimeoutError):
        return False
    return True
