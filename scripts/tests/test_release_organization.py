"""Release-list metadata cannot promote backend, fork or failed workflow runs."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))
from organize_releases import classified_title, matching_run, validate_run


class OrganizationTests(unittest.TestCase):
    def test_only_successful_owned_main_frontend_runs_are_eligible(self):
        good = {
            "status": "completed",
            "conclusion": "success",
            "head_branch": "main",
            "event": "push",
            "path": ".github/workflows/frontend-release.yml",
            "head_repository": {"full_name": "owner/repo"},
            "head_sha": "a" * 40,
        }
        self.assertEqual(validate_run(good, "owner/repo"), "a" * 40)
        self.assertEqual(
            matching_run([{**good, "id": 42}], "owner/repo", "a" * 40), "42"
        )
        with self.assertRaises(ValueError):
            matching_run([{**good, "id": 42}], "owner/repo", "b" * 40)
        for replacement in [
            {"status": "in_progress"},
            {"conclusion": "failure"},
            {"head_branch": "feature"},
            {"event": "pull_request"},
            {"path": ".github/workflows/backend.yml"},
            {"head_repository": {"full_name": "fork/repo"}},
            {"head_sha": "main"},
        ]:
            with self.assertRaises(ValueError):
                validate_run({**good, **replacement}, "owner/repo")

    def test_titles_classify_scope_without_changing_tags_or_downloads(self):
        for tag, assets, expected in [
            ("frontend-v0.8.0", [], "Web/source"),
            ("frontend-v0.11.0+15", [{"name": "app.ipa"}], "Apps"),
            ("backend-v0.15.0", [], "API"),
            ("v0.6.0", [], "API"),
            ("ios-source", [{"name": "apps.json"}], "LiveContainer source"),
        ]:
            release = {"tag_name": tag, "assets": assets, "name": "Original notes"}
            title = classified_title(release)
            self.assertIn(expected, title)
            self.assertEqual(classified_title({**release, "name": title}), title)
            self.assertEqual(release["tag_name"], tag)
            self.assertEqual(release["assets"], assets)


if __name__ == "__main__":
    unittest.main()
