"""Documentation link guards use temporary public fixtures, never real secrets."""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "check_docs", ROOT / "scripts/release/check_docs.py"
)
assert SPEC and SPEC.loader
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class DocumentationLinks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, files):
        for name, content in files.items():
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        return [Path(name) for name in files]

    def validate(self, files):
        return CHECK.validate_links(self.root, self.write(files))

    def test_same_page_cross_page_unicode_and_duplicate_heading_anchors(self):
        errors = self.validate(
            {
                "README.md": "[One](#hello-world) [Duplicate](#hello-world-1) "
                "[Collision](#hello-world-1-1) [Unicode](other.md#%E0%A4%B9%E0%A4%BF%E0%A4%A8%E0%A5%8D%E0%A4%A6%E0%A5%80)\n"
                "# Hello, world!\n## Hello world\n## Hello world-1\n",
                "other.md": "# हिन्दी\n",
            }
        )
        self.assertEqual([], errors)

    def test_setext_code_and_formatting_in_headings(self):
        errors = self.validate(
            {
                "README.md": "[API](#api-json-format) [Underlined](#underlined-title)\n"
                "# API `JSON` **format**\n\nUnderlined title\n---\n",
            }
        )
        self.assertEqual([], errors)

    def test_missing_anchor_fails_even_when_file_exists(self):
        errors = self.validate(
            {"README.md": "# Existing\n[Broken](#removed-section)\n"}
        )
        self.assertEqual(
            ["README.md:2: missing Markdown anchor #removed-section"], errors
        )

    def test_underscore_emphasis_code_and_literal_underscores(self):
        errors = self.validate(
            {
                "README.md": "[A](#emphasis-_code_-snake_case-_literal_)\n"
                "# _Emphasis_ `_code_` snake_case \\_literal\\_\n",
            }
        )
        self.assertEqual([], errors)

    def test_escaped_link_examples_and_footnotes_are_not_file_links(self):
        errors = self.validate(
            {
                "README.md": "\\[literal](missing.md) !\\[literal image](missing.png) "
                "A footnote[^1].\n\n[^1]: A sentence rather than a filename.\n",
            }
        )
        self.assertEqual([], errors)

    def test_full_collapsed_shortcut_and_image_references(self):
        errors = self.validate(
            {
                "README.md": "[Read this][Guide] [Guide][] [GUIDE] ![Picture][diagram]\n"
                "[guide]: <docs/with space.md#setup> 'Optional title'\n"
                "[diagram]: assets/diagram.svg\n",
                "docs/with space.md": "# Setup\n",
                "assets/diagram.svg": "<svg></svg>",
            }
        )
        self.assertEqual([], errors)

    def test_reference_targets_and_images_are_actually_checked(self):
        errors = self.validate(
            {
                "README.md": "[A][missing-ref] ![Picture](missing.png) [Source][manual]\n"
                "[manual]: missing.md\n",
            }
        )
        self.assertEqual(3, len(errors))
        self.assertTrue(any("undefined Markdown reference" in item for item in errors))
        self.assertTrue(
            any("missing local target missing.png" in item for item in errors)
        )
        self.assertTrue(
            any("missing local target missing.md" in item for item in errors)
        )

    def test_html_assets_links_and_explicit_anchors(self):
        errors = self.validate(
            {
                "README.md": '<a name="exact-ID"></a>\n[Jump](#exact-ID)\n'
                '<picture><source srcset="art/small.svg 400w, art/big.svg 800w">'
                '<img src="art/small.svg"></picture>\n<a href="guide.md#section">Guide</a>\n',
                "art/small.svg": "<svg></svg>",
                "art/big.svg": "<svg></svg>",
                "guide.md": "# Section\n",
            }
        )
        self.assertEqual([], errors)
        (self.root / "art/big.svg").unlink()
        errors = CHECK.validate_links(self.root, [Path("README.md"), Path("guide.md")])
        self.assertEqual(["README.md:3: missing local target art/big.svg"], errors)

    def test_examples_comments_and_code_do_not_create_links_or_anchors(self):
        errors = self.validate(
            {
                "README.md": "`[inline](missing.md)`\n```md\n[example](missing.md)\n# Not a heading\n```\n"
                "~~~\n![example](missing.png)\n~~~\n"
                "    [indented example](missing.md)\n<!-- [hidden](missing.md) -->\n"
                "# Real\n[Jump](#real)\n",
            }
        )
        self.assertEqual([], errors)
        self.assertNotIn(
            "not-a-heading", CHECK.anchors((self.root / "README.md").read_text())
        )

    def test_balanced_parentheses_angle_destinations_and_encoded_spaces(self):
        errors = self.validate(
            {
                "README.md": '[A](docs/a(b).md#part) [B](<docs/with space.md> "title") '
                "[C](docs/with%20space.md)\n",
                "docs/a(b).md": "# Part\n",
                "docs/with space.md": "# Other\n",
            }
        )
        self.assertEqual([], errors)

    def test_escaped_punctuation_in_heading_anchor(self):
        errors = self.validate(
            {"README.md": "# Name \\*value\\*\n[Jump](#name-value)\n"}
        )
        self.assertEqual([], errors)

    def test_relative_parent_links_inside_repo_are_valid(self):
        errors = self.validate(
            {
                "README.md": "# Root\n",
                "docs/guide.md": "[Root](../README.md#root)\n",
            }
        )
        self.assertEqual([], errors)

    def test_traversal_root_relative_and_windows_paths_are_rejected(self):
        errors = self.validate(
            {
                "README.md": "[Escape](%2e%2e/outside.md) [Root](/docs/guide.md) "
                "[Drive](C:/Users/private.md) [UNC](%5c%5cserver/share.md)\n",
            }
        )
        self.assertEqual(4, len(errors))
        self.assertTrue(any("escapes repository" in item for item in errors))
        self.assertTrue(any("root-relative" in item for item in errors))
        self.assertEqual(2, sum("Windows filesystem" in item for item in errors))

    def test_remote_urls_and_non_markdown_fragments_are_not_fetched(self):
        errors = self.validate(
            {
                "README.md": "[Web](https://example.invalid/#not-checked) "
                "[Remote escaped path](https://example.invalid/a%5Cb) "
                "[Email](mailto:operator@example.invalid) [Code](code.py#L900)\n",
                "code.py": "print('synthetic')\n",
            }
        )
        self.assertEqual([], errors)

    def test_ignored_markdown_is_not_opened_as_anchor_target(self):
        self.write({"private.md": "# Must not be read\n"})
        self.write({"README.md": "[Private](private.md#must-not-be-read)\n"})
        errors = CHECK.validate_links(self.root, [Path("README.md")])
        self.assertEqual(
            ["README.md:1: anchor target is not tracked documentation"], errors
        )

    def test_deleted_cached_paths_are_skipped_and_copyright_is_not_rewritten(self):
        errors = self.validate(
            {
                "README.md": "# Root\n",
                "vendor/package/README.md": "[Upstream-relative](not-distributed.md)\n",
                "licenses/upstream.md": "[Upstream-relative](not-distributed.md)\n",
            }
        )
        self.assertEqual([], errors)
        self.assertEqual([], CHECK.validate_links(self.root, [Path("deleted.md")]))

    def test_git_enumeration_does_not_discover_untracked_or_ignored_markdown(self):
        subprocess.run(["git", "init", "--quiet", str(self.root)], check=True)
        self.write(
            {
                ".gitignore": "private.md\n",
                "README.md": "# Public\n",
                "private.md": "[Ignored](missing.md)\n",
                "draft.md": "[Untracked](missing.md)\n",
            }
        )
        subprocess.run(
            ["git", "-C", str(self.root), "add", "README.md", ".gitignore"], check=True
        )
        tracked = CHECK.tracked_files(self.root)
        self.assertEqual({Path("README.md"), Path(".gitignore")}, set(tracked))
        self.assertEqual([], CHECK.validate_links(self.root, tracked))


if __name__ == "__main__":
    unittest.main()
