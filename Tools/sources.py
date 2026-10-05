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
    """Photo licences permissive enough to ship in this app.

    CC0 and CC BY carry no commercial restriction and are preferred everywhere. **CC BY-NC
    is accepted on the owner's decision (2026-09-30) that the app will be free**, and it is
    iNaturalist's default licence, so admitting it roughly doubles the pool — on
    `Smyrnium olusatrum`, 8 NZ research-grade observations become 16.

    The cost is a constraint on the app's future: an NC photo may not be distributed in
    anything commercial, so charging for the app, carrying ads, or shipping it under a
    company would mean removing every one of them first. That is survivable only because
    they stay identifiable — iNaturalist's attribution string names the licence, so an NC
    photo's `credit` contains "CC BY-NC" and the set can be found with a grep. Prefer the
    unrestricted two wherever both are available, so the set to strip stays as small as
    possible; see `is_unrestricted`.
    """

    CC0 = "cc0"
    CC_BY = "cc-by"
    CC_BY_NC = "cc-by-nc"

    @property
    def is_unrestricted(self) -> bool:
        """Whether the licence permits commercial use, and so survives the app ever selling."""
        return self is not Licence.CC_BY_NC

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


#: The catalogue every script reads and writes, located from this file so the scripts work
#: from any working directory.
CATALOGUE = Path(__file__).resolve().parent.parent / "ForageNZ" / "Catalogue" / "species.json"


def dump_catalogue(entries: list[dict[str, Any]]) -> str:
    """`species.json` exactly as Swift's `JSONEncoder` writes it, trailing newline included.

    The catalogue's last writer is usually CatalogueEditor, encoding with `.prettyPrinted`,
    `.sortedKeys` and `.withoutEscapingSlashes`. Python's `json.dumps` agrees on none of the
    three details that matter: Swift puts a space before the colon, expands an empty array
    over two lines, and leaves `/` unescaped. A tool that dumps with `json.dumps(…, indent=2)`
    therefore rewrites all ~25,000 lines whatever it changed — a four-entry edit came back as
    12,390 insertions and 17,090 deletions, which no reviewer can read and no `git diff` can
    usefully show. Going through here keeps a tool's diff to the lines it meant to touch.

    Unparameterised on purpose: the goal is one byte-exact shape, so there is nothing to tune.
    """
    return _swift_json(entries) + "\n"


def _swift_json(value: Any, indent: int = 0) -> str:
    pad, inner = "  " * indent, "  " * (indent + 1)
    if isinstance(value, dict):
        if not value:
            return "{\n\n" + pad + "}"
        body = ",\n".join(
            f"{inner}{json.dumps(key, ensure_ascii=False)} : {_swift_json(item, indent + 1)}"
            # Swift's `.sortedKeys` orders by the encoded key.
            for key, item in sorted(value.items())
        )
        return "{\n" + body + "\n" + pad + "}"
    if isinstance(value, list):
        if not value:
            return "[\n\n" + pad + "]"
        body = ",\n".join(inner + _swift_json(item, indent + 1) for item in value)
        return "[\n" + body + "\n" + pad + "]"
    # Before the int branch: `bool` is a subclass of `int`, so True would render as 1.
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    return json.dumps(value, ensure_ascii=False)


def write_catalogue(entries: list[dict[str, Any]], path: Path = CATALOGUE) -> None:
    """Write the catalogue in the editor's own shape. Use this, never `json.dumps`."""
    path.write_text(dump_catalogue(entries))


class SourceError(Exception):
    """A source could not be reached or returned something unusable.

    `status` is the HTTP status when there was one, so callers can tell a throttle (429)
    from a real failure without parsing the message.
    """

    def __init__(self, message: str, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


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
    except urllib.error.HTTPError as error:
        raise SourceError(str(error), status=error.code) from error
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
