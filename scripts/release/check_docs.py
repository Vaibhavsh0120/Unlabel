"""Check repository Markdown links and GitHub-style local heading anchors offline.

Only Git-tracked Markdown is read by the CLI. No URL is fetched, and ignored
private files are never searched to discover documentation. This is a focused
link checker, not a complete CommonMark renderer or a semantic prose review.
"""

import argparse
import html
import json
import re
import subprocess
import sys
import unicodedata
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
DEFINITION = re.compile(r"^ {0,3}\[([^\]]+)\]:\s*(.*)$")
INLINE = re.compile(r"!?\[((?:[^\[\]\n]|\[[^\]\n]*\])*)\]\(")
REFERENCE = re.compile(r"!?\[([^\]\n]+)\]\[([^\]\n]*)\]")
SHORTCUT = re.compile(r"!?\[([^\]\n]+)\]")
ATX = re.compile(r"^ {0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+[ \t]*)?$")
SETEXT = re.compile(r"^ {0,3}(?:=+|-+)[ \t]*$")
ESCAPED = re.compile(r"\\([!\"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])")


def without_code(text: str, *, inline: bool = True) -> str:
    """Preserve line numbers while excluding examples and HTML comments."""
    text = re.sub(
        r"<!--.*?-->", lambda m: "\n" * m[0].count("\n"), text, flags=re.DOTALL
    )
    lines = []
    fence = None
    for line in text.splitlines(keepends=True):
        match = FENCE.match(line)
        if fence:
            # A closing fence permits only whitespace after its marker.
            if (
                match
                and match[1][0] == fence[0]
                and len(match[1]) >= len(fence)
                and not line[match.end() :].strip()
            ):
                fence = None
            lines.append("\n" if line.endswith("\n") else "")
        elif match:
            fence = match[1]
            lines.append("\n" if line.endswith("\n") else "")
        elif line.startswith(("    ", "\t")):
            lines.append("\n" if line.endswith("\n") else "")
        else:
            lines.append(line)
    result = "".join(lines)
    if inline:
        result = re.sub(r"(`+)([^`\n]|(?!\1)`)*?\1", "", result)
    return result


def destination(value: str) -> str | None:
    """Read angle-wrapped or balanced bare destinations before optional titles."""
    value = value.lstrip()
    if value.startswith("<"):
        end = value.find(">")
        return ESCAPED.sub(r"\1", value[1:end]) if end >= 0 else None
    depth = 0
    result = []
    index = 0
    while index < len(value):
        character = value[index]
        if character == "\\" and index + 1 < len(value):
            following = value[index + 1]
            if following in "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~":
                result.extend((character, following))
                index += 2
                continue
        if character.isspace() or (character == ")" and depth == 0):
            break
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
        result.append(character)
        index += 1
    return ESCAPED.sub(r"\1", "".join(result)) if depth == 0 else None


def label(value: str) -> str:
    return " ".join(ESCAPED.sub(r"\1", value).split()).casefold()


def escaped(text: str, offset: int) -> bool:
    start = offset
    while start > 0 and text[start - 1] == "\\":
        start -= 1
    return (offset - start) % 2 == 1


class HtmlLinks(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links: list[tuple[int, str]] = []
        self.anchors: set[str] = set()

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        anchor = values.get("id") or (values.get("name") if tag == "a" else None)
        if anchor:
            self.anchors.add(anchor)
        for key in ("href", "src", "poster"):
            if values.get(key):
                self.links.append((self.getpos()[0], values[key]))
        if tag in {"img", "source"} and values.get("srcset"):
            # Repository srcsets use ordinary URL + width/density entries.
            # Data URLs are remote/inline assets and are ignored as a whole.
            srcset = values["srcset"]
            if not srcset.lstrip().startswith("data:"):
                for item in srcset.split(","):
                    if item.strip():
                        self.links.append((self.getpos()[0], item.split()[0]))


def links(text: str) -> tuple[list[tuple[int, str]], list[tuple[int, str]]]:
    text = without_code(text)
    definitions = {}
    body = []
    for line in text.splitlines(keepends=True):
        match = DEFINITION.match(line)
        if match:
            if match[1].startswith("^"):
                body.append("\n" if line.endswith("\n") else "")
                continue  # GitHub footnotes are not reference-style links.
            target = destination(match[2])
            if target is not None:
                definitions.setdefault(label(match[1]), target)
            body.append("\n" if line.endswith("\n") else "")
        else:
            body.append(line)
    body = "".join(body)
    found = []
    missing = []
    consumed = []
    for match in INLINE.finditer(body):
        if escaped(body, match.start()):
            continue
        target = destination(body[match.end() :])
        if target is not None:
            found.append((body.count("\n", 0, match.start()) + 1, target))
        consumed.append(match.span())
    for match in REFERENCE.finditer(body):
        if escaped(body, match.start()):
            continue
        key = label(match[2] or match[1])
        line_number = body.count("\n", 0, match.start()) + 1
        if key in definitions:
            found.append((line_number, definitions[key]))
        else:
            missing.append((line_number, "undefined Markdown reference"))
        consumed.append(match.span())
    for match in SHORTCUT.finditer(body):
        if escaped(body, match.start()):
            continue
        if any(start <= match.start() < end for start, end in consumed):
            continue
        key = label(match[1])
        if key in definitions:
            found.append((body.count("\n", 0, match.start()) + 1, definitions[key]))
    parser = HtmlLinks()
    parser.feed(body)
    return found + parser.links, missing


def heading_slug(value: str) -> str:
    # GitHub generates anchors from rendered heading text. Keep code contents,
    # link labels and Unicode letters/marks; remove markup and punctuation.
    value = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", value)
    value = re.sub(r"<[^>]*>", "", value)
    code = []

    def preserve_code(match):
        code.append(match[2])
        return f"\x00{len(code) - 1}\x00"

    value = re.sub(r"(`+)(.*?)\1", preserve_code, value)
    value = re.sub(r"(?<![\w\\])(_{1,3})(?=\S)(.+?)(?<=\S)\1(?!\w)", r"\2", value)
    for index, content in enumerate(code):
        value = value.replace(f"\x00{index}\x00", content)
    value = html.unescape(ESCAPED.sub(r"\1", value)).lower().strip()
    return "".join(
        character
        for character in value
        if character in " _-" or unicodedata.category(character)[0] in "LMN"
    ).replace(" ", "-")


def anchors(text: str) -> set[str]:
    body = without_code(text, inline=False)
    parser = HtmlLinks()
    parser.feed(body)
    result = set(parser.anchors)
    used = set()
    previous = ""
    for line in body.splitlines():
        match = ATX.match(line)
        heading = (
            match[1]
            if match
            else previous
            if SETEXT.fullmatch(line) and previous
            else None
        )
        if heading is not None:
            original = heading_slug(heading)
            current = original
            suffix = 0
            while current in used:
                suffix += 1
                current = f"{original}-{suffix}"
            used.add(current)
            result.add(current)
            result.add("user-content-" + current)
        previous = line.strip() if line.strip() and not match else ""
    return result


def validate_links(root: Path, paths: list[Path]) -> list[str]:
    root = root.resolve()
    errors = []
    documents = {}
    for relative in sorted(set(paths)):
        if relative.suffix.lower() != ".md" or any(
            part.lower() in {"vendor", "third_party", "licenses"}
            for part in relative.parts
        ):
            continue
        path = root / relative
        if not path.is_file():
            continue  # Git's cached list can include a deletion awaiting commit.
        if not path.resolve().is_relative_to(root):
            errors.append(
                f"{relative.as_posix()}: documentation path escapes repository"
            )
            continue
        try:
            documents[path.resolve()] = path.read_text(encoding="utf-8-sig")
        except (OSError, UnicodeError):
            errors.append(f"{relative.as_posix()}: cannot read UTF-8 Markdown")
    headings = {path: anchors(text) for path, text in documents.items()}
    for path, text in documents.items():
        source = path.relative_to(root).as_posix()
        found, missing = links(text)
        errors.extend(f"{source}:{line}: {message}" for line, message in missing)
        for line, raw in found:
            target = html.unescape(raw)
            decoded = unquote(target)
            if re.match(r"^[A-Za-z]:[\\/]", decoded) or decoded.startswith("\\"):
                errors.append(
                    f"{source}:{line}: Windows filesystem link cannot work on GitHub"
                )
                continue
            try:
                url = urlsplit(target)
            except ValueError:
                errors.append(f"{source}:{line}: malformed link destination")
                continue
            if url.scheme or url.netloc:
                continue
            local = unquote(url.path)
            if "\\" in local:
                errors.append(
                    f"{source}:{line}: Windows filesystem link cannot work on GitHub"
                )
                continue
            if local.startswith("/"):
                errors.append(
                    f"{source}:{line}: root-relative link must be repository-relative"
                )
                continue
            linked = (path.parent / local).resolve() if local else path
            if not linked.is_relative_to(root):
                errors.append(f"{source}:{line}: local link escapes repository")
                continue
            if not linked.exists():
                errors.append(f"{source}:{line}: missing local target {local}")
                continue
            if url.fragment and linked.suffix.lower() == ".md":
                if linked not in headings:
                    errors.append(
                        f"{source}:{line}: anchor target is not tracked documentation"
                    )
                elif unquote(url.fragment) not in headings[linked]:
                    errors.append(
                        f"{source}:{line}: missing Markdown anchor #{unquote(url.fragment)}"
                    )
    return errors


def tracked_files(root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--cached", "-z"],
        capture_output=True,
        check=True,
    )
    return [Path(name.decode("utf-8")) for name in result.stdout.split(b"\0") if name]


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        errors = validate_links(ROOT, tracked_files(ROOT))
    except (OSError, UnicodeError, subprocess.CalledProcessError):
        print("Unable to enumerate tracked documentation.", file=sys.stderr)
        return 1
    print(json.dumps({"errors": errors}, ensure_ascii=True, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
