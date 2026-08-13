import sys
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = REPO_ROOT / "apps" / "aida1145"

if str(APP_ROOT) not in sys.path:
    sys.path.insert(0, str(APP_ROOT))


@pytest.fixture(scope="session")
def app_root() -> Path:
    return APP_ROOT


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT
