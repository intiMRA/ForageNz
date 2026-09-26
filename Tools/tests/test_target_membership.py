"""The model is compiled by SwiftPM and by Xcode; this is the seam that can drift."""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_target_membership as membership  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_every_model_source_is_compiled_by_both_apps(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    assert membership.find_drift() == []


def test_an_unlisted_file_is_reported(monkeypatch, tmp_path):
    """Otherwise a check that always passes tells us nothing."""
    monkeypatch.chdir(REPO_ROOT)
    probe = membership.MODEL_DIR / "DriftProbe.swift"
    probe.write_text("// added without touching the project\n")
    try:
        problems = membership.find_drift()
    finally:
        os.unlink(probe)
    assert any("DriftProbe.swift" in problem for problem in problems)
