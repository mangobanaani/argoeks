#!/usr/bin/env python3
"""Developer CLI for common ArgoEKS workflows."""

from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, Any

REPO_ROOT = Path(__file__).resolve().parents[1]


def run_subprocess(cmd: list[str], dry_run: bool = False, verbose: bool = False) -> int:
    printable = " ".join(shlex.quote(part) for part in cmd)
    if verbose or dry_run:
        print(f"$ {printable}")
    if dry_run:
        return 0
    completed = subprocess.run(cmd)
    return completed.returncode


def handle_env_command(args: argparse.Namespace) -> int:
    env = args.env
    region = args.region
    base = ["make"]

    if args.action == "plan":
        cmd = base + ["plan-env", f"ENV={env}", f"REGION={region}"]
    elif args.action == "apply":
        cmd = base + ["apply-env", f"ENV={env}", f"REGION={region}"]
        if args.auto_approve:
            cmd.append("AUTO_APPROVE=true")
    elif args.action == "destroy":
        cmd = base + ["destroy-env", f"ENV={env}", f"REGION={region}"]
    elif args.action == "output":
        cmd = base + ["output", f"ENV={env}"]
    else:
        raise ValueError(f"Unknown env action {args.action}")

    return run_subprocess(cmd, args.dry_run, args.verbose)


def handle_docs_command(args: argparse.Namespace) -> int:
    doc_path = REPO_ROOT / args.path
    if not doc_path.exists():
        raise SystemExit(f"{doc_path} does not exist")
    print(doc_path)
    if args.print_only:
        return 0
    try:
        return run_subprocess(["less", str(doc_path)], args.dry_run, args.verbose)
    except subprocess.CalledProcessError as exc:
        print(f"less exited with {exc.returncode}, file path printed above", file=sys.stderr)
        return exc.returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ArgoEKS developer CLI")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without executing them")
    parser.add_argument("--verbose", action="store_true", help="Echo commands before running")
    subparsers = parser.add_subparsers(dest="command", required=True)

    env_parser = subparsers.add_parser("env", help="Environment level commands")
    env_sub = env_parser.add_subparsers(dest="action", required=True)

    for subcmd in ("plan", "apply", "destroy", "output"):
        sub = env_sub.add_parser(subcmd, help=f"{subcmd.title()} environment")
        sub.add_argument("--env", default="dev", help="Environment name (default: dev)")
        if subcmd in {"plan", "apply", "destroy"}:
            sub.add_argument("--region", default="us-east-1", help="AWS region")
        if subcmd == "apply":
            sub.add_argument("--auto-approve", action="store_true", help="Skip approval prompts")
        sub.set_defaults(handler=handle_env_command)

    docs_parser = subparsers.add_parser("docs", help="Documentation utilities")
    docs_parser.add_argument("--path", required=True, help="Path to open, relative to repo root (e.g., docs/QuickStart.md)")
    docs_parser.add_argument("--print-only", action="store_true", help="Only print the file path")
    docs_parser.set_defaults(handler=handle_docs_command)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    handler = getattr(args, "handler", None)
    if handler is None:
        parser.error("No command provided")
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
