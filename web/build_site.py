#!/usr/bin/env python3
"""Insert README.md into an already-exported Godot website HTML page.

The source README remains unchanged. Relative README image paths are copied next
into the website's output; other repository-relative links go to GitHub.
"""

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path, PurePosixPath
from urllib.parse import quote, urlsplit, urlunsplit

from bs4 import BeautifulSoup, NavigableString
from markdown_it import MarkdownIt

ROOT = Path(__file__).resolve().parent.parent
START = '<!-- BEGIN_GENERATED_README -->'
END = '<!-- END_GENERATED_README -->'


def git_origin_url() -> str | None:
    """Try the current repository's origin as a convenience for local testing."""
    result = subprocess.run(
        ['git', '-C', str(ROOT), 'remote', 'get-url', 'origin'],
        check=False, capture_output=True, text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def normalize_repo_url(raw_url: str) -> str:
    """Accept a normal github.com URL or a common git remote URL."""
    raw_url = raw_url.strip().rstrip('/')
    ssh_match = re.fullmatch(r'git@github\.com:([\w.-]+/[\w.-]+?)(?:\.git)?', raw_url)
    if ssh_match:
        return 'https://github.com/' + ssh_match.group(1)
    parsed = urlsplit(raw_url)
    if parsed.hostname != 'github.com' or parsed.scheme not in ('https', 'http'):
        raise ValueError('Expected a github.com repository URL, e.g. https://github.com/OWNER/REPO')
    path = parsed.path.removesuffix('.git').strip('/')
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', path):
        raise ValueError('Expected https://github.com/OWNER/REPO (without a subdirectory)')
    return 'https://github.com/' + path


def github_slug(text: str) -> str:
    """Create approximate GitHub-style heading anchors for common README headings."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\- ]', '', text, flags=re.UNICODE)
    return re.sub(r' +', '-', text)


def local_reference(url: str) -> tuple[str, str, str] | None:
    """Return path, query, fragment for safe, repository-relative references."""
    parts = urlsplit(url)
    if parts.scheme or parts.netloc or url.startswith(('/', '#', '\\')):
        return None
    path = parts.path.replace('\\', '/')
    if not path:
        return None
    normalized = PurePosixPath(path)
    if any(p in ('..', '.') for p in normalized.parts):
        raise ValueError(f'Unsafe README path: {url!r}')
    return str(normalized), parts.query, parts.fragment


def build_readme(readme_path: Path, output_dir: Path, repo_url: str, branch: str) -> str:
    text = readme_path.read_text(encoding='utf-8')
    markdown = MarkdownIt('commonmark', {'html': True}).enable(['table', 'strikethrough'])
    soup = BeautifulSoup(markdown.render(text), 'html.parser')

    # Generate stable IDs for in-page anchors such as #third-party-resources.
    seen: dict[str, int] = {}
    for heading in soup.find_all(re.compile(r'^h[1-6]$')):
        base = github_slug(heading.get_text(' ', strip=True))
        counter = seen.get(base, 0)
        heading['id'] = base if counter == 0 else f'{base}-{counter}'
        seen[base] = counter + 1

    # CommonMark emits task-list text; convert it into disabled checkboxes.
    for li in soup.find_all('li'):
        if not li.contents or not isinstance(li.contents[0], NavigableString):
            continue
        first = str(li.contents[0])
        match = re.match(r'^\s*\[([ xX])\]\s+', first)
        if not match:
            continue
        checked = match.group(1).lower() == 'x'
        li.contents[0].replace_with(first[match.end():])
        checkbox = soup.new_tag('input', type='checkbox', disabled='')
        if checked:
            checkbox['checked'] = ''
        li.insert(0, checkbox)
        li['class'] = ['task-list-item']

    # Keep screenshots local to the deployed page, so relative paths work as on GitHub.
    for img in soup.find_all('img'):
        src = img.get('src', '')
        local = local_reference(src)
        if not local:
            continue
        relative_path, query, fragment = local
        source = ROOT / Path(relative_path)
        if not source.is_file():
            raise FileNotFoundError(f'README image not found: {relative_path}')
        target = output_dir / Path(relative_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        img['src'] = urlunsplit(('', '', quote(relative_path, safe='/'), query, fragment))

    # Internal anchors stay on this page; relative file links open in the GitHub repo.
    for a in soup.find_all('a', href=True):
        href = a['href']
        local = local_reference(href)
        if not local:
            continue
        relative_path, query, fragment = local
        target = ROOT / Path(relative_path)
        repo_action = 'tree' if target.is_dir() else 'blob'
        remote = f'{repo_url}/{repo_action}/{quote(branch, safe="/")}/{quote(relative_path, safe="/")}'
        a['href'] = urlunsplit(urlsplit(remote)._replace(query=query, fragment=fragment))
    return str(soup)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--html', type=Path, default=ROOT / 'builds/web-website/index.html',
                        help='Godot website export HTML to update')
    parser.add_argument('--repo-url', default=os.getenv('GITHUB_REPOSITORY_URL') or git_origin_url(),
                        help='Repository URL (defaults to GitHub env or git origin)')
    parser.add_argument('--branch', default=os.getenv('REPO_DEFAULT_BRANCH', 'main'),
                        help='Default GitHub branch, normally main')
    args = parser.parse_args()
    if not args.repo_url:
        parser.error('No git origin found; supply --repo-url https://github.com/OWNER/REPO')
    repo_url = normalize_repo_url(args.repo_url)
    html = args.html.resolve()
    if not html.is_file():
        parser.error(f'Export not found: {html}. Export Web - Website from Godot first.')
    source = html.read_text(encoding='utf-8')
    if source.count(START) != 1 or source.count(END) != 1:
        parser.error('Generated README markers missing. Confirm Web - Website uses web/shell.html.')
    html_section = build_readme(ROOT / 'README.md', html.parent, repo_url, args.branch)
    pattern = re.compile(re.escape(START) + r'.*?' + re.escape(END), re.DOTALL)
    result = pattern.sub(lambda _: f'{START}\n{html_section}\n{END}', source)
    html.write_text(result, encoding='utf-8')
    (html.parent / '.nojekyll').touch()
    print('Website documentation generated:', html)
    print('Repository links target:', f'{repo_url}/blob/{args.branch}/...')


if __name__ == '__main__':
    main()
