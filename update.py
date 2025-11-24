#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nix-prefetch --command python3

"""Update script for claude package.

Claude Code provides version info at a stable endpoint and distributes
platform-specific binaries.

Inspired by:
https://github.com/numtide/nix-ai-tools/blob/91132d4e72ed07374b9d4a718305e9282753bac9/packages/coderabbit-cli/update.py
"""

import re
import subprocess
from pathlib import Path
from urllib.request import urlopen


def fetch_claude_version() -> str:
    """Fetch the latest version from Claude Code's stable endpoint."""
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/stable"
    with urlopen(url) as response:
        return response.read().decode("utf-8").strip()


def nix_prefetch_url(url: str) -> str:
    """Prefetch a URL and return its nix hash in SRI format."""
    result = subprocess.run(
        ["nix-prefetch-url", "--type", "sha256", url],
        capture_output=True,
        text=True,
        check=True,
    )
    hash_output = result.stdout.strip()

    # Convert to SRI format
    result_sri = subprocess.run(
        ["nix", "hash", "to-sri", "--type", "sha256", hash_output],
        capture_output=True,
        text=True,
        check=True,
    )
    return result_sri.stdout.strip()


def get_current_version() -> str | None:
    """Get the current version from default.nix."""
    default_nix = Path(__file__).parent / "default.nix"
    content = default_nix.read_text()

    match = re.search(r'version = "([^"]+)";', content)
    return match.group(1) if match else None


def update_default_nix(version: str, hashes: dict[str, str]) -> None:
    """Update default.nix with new version and hashes using regex."""
    default_nix = Path(__file__).parent / "default.nix"
    content = default_nix.read_text()

    # Update version
    content = re.sub(
        r'version = "[^"]+";',
        f'version = "{version}";',
        content,
        count=1,
    )

    # Update each platform hash
    for platform, hash_value in hashes.items():
        # Match the platform block and update its hash
        pattern = rf'({platform} = \{{[^}}]*?hash = ")[^"]+(")'
        content = re.sub(pattern, rf'\g<1>{hash_value}\g<2>', content, flags=re.DOTALL)

    default_nix.write_text(content)


def main() -> None:
    """Update the claude package."""
    current_version = get_current_version()
    latest_version = fetch_claude_version()

    print(f"Current version: {current_version}")
    print(f"Latest version: {latest_version}")

    if current_version == latest_version:
        print("claude is already up to date")
        return

    print(f"Updating claude from {current_version} to {latest_version}")

    # Define platforms
    platforms = {
        "x86_64-linux": "linux-x64",
        "aarch64-linux": "linux-arm64",
        "x86_64-darwin": "darwin-x64",
        "aarch64-darwin": "darwin-arm64",
    }

    # Fetch hashes for all platforms
    hashes = {}
    base_url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

    for platform, url_arch in platforms.items():
        url = f"{base_url}/{latest_version}/{url_arch}/claude"
        print(f"Fetching hash for {platform}...")
        hashes[platform] = nix_prefetch_url(url)
        print(f"  {platform}: {hashes[platform]}")
        print()

    # Update default.nix
    update_default_nix(latest_version, hashes)
    print(f"Updated claude to version {latest_version}")


if __name__ == "__main__":
    main()
