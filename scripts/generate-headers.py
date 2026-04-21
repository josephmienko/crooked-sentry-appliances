#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_DARK_LOGO = REPO_ROOT / "_includes" / "logos" / "auth-logo-dark.svg"
DEFAULT_LIGHT_LOGO = REPO_ROOT / "_includes" / "logos" / "auth-logo-light.svg"

TITLE_FONT_FAMILY = '-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif'
# Match the GitHub Pages/README text color more closely in each theme variant.
TITLE_FILL = {
    "dark": "#f0f6fc",
    "light": "#0d1117",
}
OUTPUT_FILES = {
    ("wide", "dark"): "header-wide-dark-inline.svg",
    ("wide", "light"): "header-wide-light-inline.svg",
    ("stacked", "dark"): "header-stacked-dark-inline.svg",
    ("stacked", "light"): "header-stacked-light-inline.svg",
}
STALE_SVG_FILES = {
    "auth-logo-light-small.svg",
    "auth-logo-light.svg",
    "header-stacked.svg",
    "header-stacked-inline.svg",
    "header-wide.svg",
    "header-wide-inline.svg",
    "repo-title.svg",
    *OUTPUT_FILES.values(),
}

PAGES_CONFIG_TEXT = "title: null\n"
PAGES_HEAD_CUSTOM_HTML = """<style>
  .markdown-body > h1:first-of-type {
    display: none;
  }

  @media (prefers-color-scheme: dark) {
    html,
    body {
      background: #0d1117;
    }

    body,
    .markdown-body,
    .markdown-body p,
    .markdown-body li,
    .markdown-body blockquote {
      color: #c9d1d9;
    }

    .container-lg {
      background: #0d1117;
    }

    .markdown-body h1,
    .markdown-body h2,
    .markdown-body h3,
    .markdown-body h4,
    .markdown-body h5,
    .markdown-body h6 {
      color: #f0f6fc;
      border-bottom-color: #21262d;
    }

    .markdown-body hr {
      background-color: #21262d;
    }

    .markdown-body a {
      color: #58a6ff;
    }

    .markdown-body code,
    .markdown-body tt {
      background-color: rgba(110, 118, 129, 0.4);
    }

    .markdown-body pre {
      background-color: #161b22;
    }

    .markdown-body pre code {
      background: transparent;
    }

    .markdown-body table tr {
      background-color: #0d1117;
      border-top-color: #21262d;
    }

    .markdown-body table tr:nth-child(2n) {
      background-color: #161b22;
    }

    .markdown-body table th,
    .markdown-body table td {
      border-color: #30363d;
    }

    .markdown-body blockquote {
      border-left-color: #30363d;
    }

    .markdown-body img {
      background: transparent;
    }
  }
</style>
"""


def run_git(repo_dir: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo_dir), *args],
        text=True,
    ).strip()


def parse_github_remote(remote_url: str) -> tuple[str, str]:
    ssh_match = re.fullmatch(r"git@github\.com:(?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?", remote_url)
    https_match = re.fullmatch(r"https://github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?", remote_url)
    match = ssh_match or https_match
    if not match:
        raise ValueError(f"unsupported GitHub remote URL: {remote_url}")
    return match.group("owner"), match.group("repo")


def repo_identity(repo_dir: Path) -> tuple[str, str]:
    remote_url = run_git(repo_dir, "config", "--get", "remote.origin.url")
    return parse_github_remote(remote_url)


def load_svg_body(svg_path: Path) -> tuple[str, str, str]:
    source = svg_path.read_text(encoding="utf-8")
    source = re.sub(r"<\?xml[^>]*\?>\s*", "", source, count=1, flags=re.DOTALL)
    source = re.sub(r"<!--.*?-->\s*", "", source, flags=re.DOTALL)
    match = re.search(r"<svg\b(?P<attrs>[^>]*)>(?P<body>.*)</svg>\s*$", source, flags=re.DOTALL)
    if not match:
        raise ValueError(f"failed to parse svg root in {svg_path}")

    attrs = match.group("attrs")
    body = match.group("body").strip()
    view_box_match = re.search(r'viewBox="([^"]+)"', attrs)
    if not view_box_match:
        raise ValueError(f"missing viewBox in {svg_path}")

    extra_attrs = " ".join(
        re.findall(r'((?:xmlns(?::[a-zA-Z0-9_-]+)?|xml:space)="[^"]+")', attrs)
    )

    return view_box_match.group(1), extra_attrs, body


def build_wide_svg(repo_name: str, theme: str, logo_view_box: str, logo_extra_attrs: str, logo_body: str) -> str:
    escaped_repo_name = escape(repo_name)
    fill = TITLE_FILL[theme]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="140" viewBox="0 0 1400 140" role="img" aria-labelledby="title desc">
  <title id="title">{escaped_repo_name} header</title>
  <desc id="desc">Wide repository header with title on the left and the {theme} Crooked Sentry logo on the right.</desc>
  <text x="0" y="92" fill="{fill}" font-family='{TITLE_FONT_FAMILY}' font-size="64" font-weight="700">{escaped_repo_name}</text>
  <svg x="1190" y="10" width="190" height="120" viewBox="{logo_view_box}" preserveAspectRatio="xMidYMid meet" {logo_extra_attrs}>
{logo_body}
  </svg>
</svg>
"""


def build_stacked_svg(repo_name: str, theme: str, logo_view_box: str, logo_extra_attrs: str, logo_body: str) -> str:
    escaped_repo_name = escape(repo_name)
    fill = TITLE_FILL[theme]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="920" height="260" viewBox="0 0 920 260" role="img" aria-labelledby="title desc">
  <title id="title">{escaped_repo_name} header</title>
  <desc id="desc">Stacked repository header with the {theme} Crooked Sentry logo above the centered title.</desc>
  <svg x="340" y="8" width="240" height="150" viewBox="{logo_view_box}" preserveAspectRatio="xMidYMid meet" {logo_extra_attrs}>
{logo_body}
  </svg>
  <text x="460" y="220" text-anchor="middle" fill="{fill}" font-family='{TITLE_FONT_FAMILY}' font-size="56" font-weight="700">{escaped_repo_name}</text>
</svg>
"""


def readme_header_block(owner: str, repo_name: str) -> str:
    return f"""<p align="center">
  <picture>
    <!-- Desktop Dark Mode -->
    <source media="(min-width: 769px) and (prefers-color-scheme: dark)" srcset="_includes/header-wide-dark-inline.svg">
    <!-- Desktop Light Mode -->
    <source media="(min-width: 769px) and (prefers-color-scheme: light)" srcset="_includes/header-wide-light-inline.svg">
    <!-- Mobile Dark Mode -->
    <source media="(max-width: 768px) and (prefers-color-scheme: dark)" srcset="_includes/header-stacked-dark-inline.svg">
    <!-- Mobile Light Mode -->
    <source media="(max-width: 768px) and (prefers-color-scheme: light)" srcset="_includes/header-stacked-light-inline.svg">
    <img src="_includes/header-wide-light-inline.svg" alt="{repo_name}" />
  </picture>
</p>

<p align="left">
  Part of the Crooked Sentry universe&nbsp;|&nbsp;
  <a href="https://github.com/{owner}/{repo_name}/actions/workflows/validate.yml"><img src="https://github.com/{owner}/{repo_name}/actions/workflows/validate.yml/badge.svg" alt="Validate" align="absmiddle" /></a>&nbsp;
  <a href="https://app.codecov.io/gh/{owner}/{repo_name}"><img src="https://codecov.io/gh/{owner}/{repo_name}/badge.svg" alt="Codecov test coverage" align="absmiddle" /></a>
</p>

"""


def update_readme(repo_dir: Path, owner: str, repo_name: str) -> None:
    readme_path = repo_dir / "README.md"
    source = readme_path.read_text(encoding="utf-8")
    pattern = re.compile(r"\A.*?(?=## Overview\b)", re.DOTALL)
    replacement = readme_header_block(owner, repo_name)
    updated, count = pattern.subn(replacement, source, count=1)
    if count != 1:
        raise ValueError(f"failed to locate README header block in {readme_path}")
    readme_path.write_text(updated, encoding="utf-8")


def ensure_pages_files(repo_dir: Path) -> None:
    (repo_dir / "_config.yml").write_text(PAGES_CONFIG_TEXT, encoding="utf-8")
    includes_dir = repo_dir / "_includes"
    includes_dir.mkdir(parents=True, exist_ok=True)
    (includes_dir / "head-custom.html").write_text(PAGES_HEAD_CUSTOM_HTML, encoding="utf-8")


def prune_stale_svgs(repo_dir: Path) -> None:
    includes_dir = repo_dir / "_includes"
    active_include_paths = {includes_dir / name for name in OUTPUT_FILES.values()}

    for directory in (repo_dir, includes_dir):
        if not directory.exists():
            continue
        for svg_path in directory.glob("*.svg"):
            if svg_path in active_include_paths:
                continue
            if svg_path.name in STALE_SVG_FILES:
                svg_path.unlink()


def generate_headers(
    repo_dir: Path,
    dark_logo_path: Path,
    light_logo_path: Path,
    update_readme_flag: bool,
) -> None:
    owner, repo_name = repo_identity(repo_dir)
    includes_dir = repo_dir / "_includes"
    includes_dir.mkdir(parents=True, exist_ok=True)
    logo_assets = {
        "dark": load_svg_body(dark_logo_path),
        "light": load_svg_body(light_logo_path),
    }

    for layout in ("wide", "stacked"):
        for theme in ("dark", "light"):
            logo_view_box, logo_extra_attrs, logo_body = logo_assets[theme]
            if layout == "wide":
                svg_text = build_wide_svg(repo_name, theme, logo_view_box, logo_extra_attrs, logo_body)
            else:
                svg_text = build_stacked_svg(repo_name, theme, logo_view_box, logo_extra_attrs, logo_body)

            (includes_dir / OUTPUT_FILES[(layout, theme)]).write_text(svg_text, encoding="utf-8")

    if update_readme_flag:
        update_readme(repo_dir, owner, repo_name)

    ensure_pages_files(repo_dir)
    prune_stale_svgs(repo_dir)

    print(f"updated {repo_name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate README header SVG variants for GitHub repos.")
    parser.add_argument("repo_dirs", nargs="+", help="Paths to git repositories to update.")
    parser.add_argument(
        "--dark-logo",
        default=str(DEFAULT_DARK_LOGO),
        help="Path to the dark-mode logo SVG.",
    )
    parser.add_argument(
        "--light-logo",
        default=str(DEFAULT_LIGHT_LOGO),
        help="Path to the light-mode logo SVG.",
    )
    parser.add_argument(
        "--update-readme",
        action="store_true",
        help="Rewrite the README header block to use the generated themed header assets.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dark_logo_path = Path(args.dark_logo).resolve()
    light_logo_path = Path(args.light_logo).resolve()

    for logo_path in (dark_logo_path, light_logo_path):
        if not logo_path.is_file():
            raise FileNotFoundError(f"logo not found: {logo_path}")

    for repo in args.repo_dirs:
        generate_headers(
            repo_dir=Path(repo).resolve(),
            dark_logo_path=dark_logo_path,
            light_logo_path=light_logo_path,
            update_readme_flag=args.update_readme,
        )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
