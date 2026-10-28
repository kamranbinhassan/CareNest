"""Create backend/.env with fresh, URL-safe local development secrets."""

from pathlib import Path
import os
import secrets
import sys


BACKEND_DIR = Path(__file__).resolve().parents[1]
EXAMPLE = BACKEND_DIR / ".env.example"
ENV_FILE = BACKEND_DIR / ".env"


def main() -> int:
    if ENV_FILE.exists():
        print("backend/.env already exists; left unchanged.")
        return 0
    template = EXAMPLE.read_text()
    content = template.replace(
        "REPLACE_WITH_LOCAL_PASSWORD", secrets.token_hex(32)
    ).replace("REPLACE_WITH_AT_LEAST_32_RANDOM_BYTES", secrets.token_urlsafe(48))
    if "REPLACE_WITH_" in content:
        print("Unknown placeholder in backend/.env.example", file=sys.stderr)
        return 2
    tmp = BACKEND_DIR / ".env.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(tmp, ENV_FILE)
    os.chmod(ENV_FILE, 0o600)
    print("Created backend/.env with a random local DB password and separate JWT secret; values not displayed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
