#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

"""
Constants for Claude Code Hooks.

Supports two modes:
1. ADW mode: When ADW_ID and ADW_ISSUE_ID are set, logs go to ~/.adw/workflows/
2. Standalone mode: Logs go to local 'logs/' directory
"""

import os
from pathlib import Path

# ADW context from environment (set by ADW SDK when spawning Claude)
ADW_ID = os.environ.get("ADW_ID")
ADW_ISSUE_ID = os.environ.get("ADW_ISSUE_ID")
ADW_PHASE = os.environ.get("ADW_PHASE")

# Base directory for non-ADW logs
LOCAL_LOG_DIR = os.environ.get("CLAUDE_HOOKS_LOG_DIR", "logs")


def get_workflows_base_dir() -> Path:
    """Get the base directory for ADW workflow logs."""
    return Path.home() / ".adw" / "workflows"


def get_session_log_dir(session_id: str) -> Path:
    """
    Get the log directory for a specific session.

    If ADW context is available, returns:
        ~/.adw/workflows/{issue_id}/{adw_id}/sessions/{session_id}/
    Otherwise returns:
        ./logs/{session_id}/

    Args:
        session_id: The Claude session ID

    Returns:
        Path object for the session's log directory
    """
    if ADW_ID and ADW_ISSUE_ID:
        return get_workflows_base_dir() / ADW_ISSUE_ID / ADW_ID / "sessions" / session_id
    else:
        return Path(LOCAL_LOG_DIR) / session_id


def ensure_session_log_dir(session_id: str) -> Path:
    """
    Ensure the log directory for a session exists.

    Args:
        session_id: The Claude session ID

    Returns:
        Path object for the session's log directory
    """
    log_dir = get_session_log_dir(session_id)
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def get_workflow_log_dir() -> Path:
    """
    Get the workflow log directory (for execution.log, workflow.json).

    Returns:
        Path to ~/.adw/workflows/{issue_id}/{adw_id}/ if ADW context available,
        otherwise None
    """
    if ADW_ID and ADW_ISSUE_ID:
        return get_workflows_base_dir() / ADW_ISSUE_ID / ADW_ID
    return None


def get_adw_context() -> dict:
    """
    Get current ADW context from environment.

    Returns:
        Dict with adw_id, issue_id, and phase (any may be None)
    """
    return {
        "adw_id": ADW_ID,
        "issue_id": ADW_ISSUE_ID,
        "phase": ADW_PHASE,
    }
