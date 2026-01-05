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


def test_docs_status(monkeypatch, tmp_path):
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    cli.main(["docs", "status"])
    assert runner.calls[0][0][0].endswith("check-doc-freshness.sh")


def test_docs_open_print_only(monkeypatch):
    monkeypatch.setattr(cli, "load_docs", lambda: {"quick start": {"name": "Quick Start", "path": "docs/QuickStart.md"}})
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    cli.main(["docs", "open", "--name", "Quick Start", "--print-only"])
    assert runner.calls == []


def test_docs_open_runs_less(monkeypatch):
    monkeypatch.setattr(cli, "load_docs", lambda: {"readme": {"name": "Root README", "path": "README.md"}})
    runner = Runner()
    monkeypatch.setattr(cli, "run_subprocess", runner)
    cli.main(["docs", "open", "--name", "readme"])
    assert runner.calls[0][0][0] == "less"
