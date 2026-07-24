import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from inspect_prompt_config import inspect


class InspectPromptConfigTests(unittest.TestCase):
    def fixture(self) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        return Path(temp.name)

    def test_reports_correct_claude_symlink(self):
        root = self.fixture()
        (root / "AGENTS.md").write_text("# Rules\n", encoding="utf-8")
        (root / "CLAUDE.md").symlink_to("AGENTS.md")
        report = inspect(root, root / "global-pi")
        self.assertEqual(report["claude_link"]["status"], "correct")

    def test_reports_regular_file_and_unique_content(self):
        root = self.fixture()
        (root / "AGENTS.md").write_text("shared\n", encoding="utf-8")
        (root / "CLAUDE.md").write_text("claude only\n", encoding="utf-8")
        report = inspect(root, root / "global-pi")
        self.assertEqual(report["claude_link"]["status"], "regular-file")
        self.assertTrue(report["claude_link"]["content_differs"])

    def test_reports_wrong_and_broken_links(self):
        root = self.fixture()
        (root / "AGENTS.md").write_text("shared\n", encoding="utf-8")
        (root / "other.md").write_text("other\n", encoding="utf-8")
        (root / "CLAUDE.md").symlink_to("other.md")
        self.assertEqual(inspect(root, root / "g")["claude_link"]["status"], "wrong-target")
        (root / "CLAUDE.md").unlink()
        (root / "CLAUDE.md").symlink_to("missing.md")
        self.assertEqual(inspect(root, root / "g")["claude_link"]["status"], "broken")

    def test_reports_project_and_global_pi_prompt_files(self):
        root = self.fixture()
        (root / ".pi").mkdir()
        (root / ".pi" / "SYSTEM.md").write_text("replace\n", encoding="utf-8")
        global_pi = root / "global-pi"
        global_pi.mkdir()
        (global_pi / "APPEND_SYSTEM.md").write_text("append\n", encoding="utf-8")
        report = inspect(root, global_pi)
        paths = {item["path"] for item in report["files"] if item["exists"]}
        self.assertIn(".pi/SYSTEM.md", paths)
        self.assertIn(str(global_pi / "APPEND_SYSTEM.md"), paths)
        self.assertIn("replacement-system-prompt", report["warnings"])

    def test_duplicate_headings_are_normalized(self):
        root = self.fixture()
        (root / "AGENTS.md").write_text("# Safety\nA\n## safety\nB\n", encoding="utf-8")
        report = inspect(root, root / "g")
        self.assertEqual(report["duplicate_headings"]["safety"], [1, 3])

    def test_correct_claude_symlink_does_not_duplicate_all_headings(self):
        root = self.fixture()
        (root / "AGENTS.md").write_text("# Safety\n", encoding="utf-8")
        (root / "CLAUDE.md").symlink_to("AGENTS.md")
        self.assertEqual(inspect(root, root / "g")["duplicate_headings"], {})


if __name__ == "__main__":
    unittest.main()
