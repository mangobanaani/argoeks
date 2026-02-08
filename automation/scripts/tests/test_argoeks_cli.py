import types

import pytest

import scripts.argoeks as cli


class Runner:
    def __init__(self):
        self.calls = []

    def __call__(self, cmd, dry_run=False, verbose=False):
        self.calls.append((cmd, dry_run, verbose))
        return 0


def test_env_plan_invokes_make(monkeypatch):
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    args = ["env", "plan", "--env", "qa", "--region", "eu-west-1", "--verbose"]
    cli.main(args)
    assert runner.calls == [(
        ["make", "plan-env", "ENV=qa", "REGION=eu-west-1"],
        False,
        True,
    )]


def test_env_apply_auto_approve(monkeypatch):
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    cli.main(["--dry-run", "env", "apply", "--env", "dev", "--region", "us-east-1", "--auto-approve"])
    assert runner.calls == [(
        ["make", "apply-env", "ENV=dev", "REGION=us-east-1", "AUTO_APPROVE=true"],
        True,
        False,
    )]


def test_docs_print_only(monkeypatch, tmp_path):
    doc = tmp_path / "test.md"
    doc.write_text("hello")
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    monkeypatch.setattr(cli, "REPO_ROOT", tmp_path)
    rc = cli.main(["docs", "--path", "test.md", "--print-only"])
    assert rc == 0
    assert runner.calls == []


def test_docs_runs_less(monkeypatch, tmp_path):
    doc = tmp_path / "README.md"
    doc.write_text("readme")
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    monkeypatch.setattr(cli, "REPO_ROOT", tmp_path)
    cli.main(["docs", "--path", "README.md"])
    assert runner.calls[0][0][0] == "less"
