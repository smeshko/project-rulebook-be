#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

import json
import os
import sys
from datetime import datetime
from pathlib import Path

from utils.constants import ensure_session_log_dir, get_adw_context

# Maximum size for commands.log before truncation (1MB)
MAX_LOG_SIZE = 1024 * 1024


def append_to_commands_log(log_dir: Path, input_data: dict) -> None:
    """Append tool execution to human-readable commands.log.

    Format:
        2024-01-15 14:32:15 | Bash     | npm install
        2024-01-15 14:32:27 | RESULT   | SUCCESS: added 245 packages in 12s

    Args:
        log_dir: Session log directory
        input_data: Tool call data from Claude Code
    """
    log_path = log_dir / "commands.log"
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    tool_name = input_data.get("tool_name", "unknown")
    tool_input = input_data.get("tool_input", {})
    tool_response = input_data.get("tool_response", {})

    # Format action based on tool type
    if tool_name == "Bash":
        action = tool_input.get("command", "")[:100]
    elif tool_name in ("Read", "Write", "Edit"):
        action = tool_input.get("file_path", "")[:100]
    elif tool_name == "Grep":
        pattern = tool_input.get("pattern", "")
        action = f"pattern='{pattern}'"[:100]
    elif tool_name == "Glob":
        pattern = tool_input.get("pattern", "")
        action = f"glob='{pattern}'"[:100]
    elif tool_name == "Task":
        desc = tool_input.get("description", "")
        action = f"agent: {desc}"[:100]
    else:
        action = str(tool_input)[:100]

    # Format result based on tool type
    if tool_name == "Bash":
        # Handle both simple and task-wrapped response formats
        if "task" in tool_response:
            task = tool_response["task"]
            exit_code = task.get("exitCode", 0)
            output = task.get("output", "")
        else:
            exit_code = tool_response.get("exitCode", 0)
            output = tool_response.get("stdout", "") or tool_response.get("stderr", "")

        status = "SUCCESS" if exit_code == 0 else "FAILURE"
        output_summary = output.split('\n')[0][:80] if output else ""
        result_line = f"{status}: {output_summary}"
    elif tool_name in ("Read", "Write", "Edit", "Glob", "Grep"):
        # File operations - just show success
        if isinstance(tool_response, str):
            lines = len(tool_response.split('\n'))
            result_line = f"SUCCESS: {lines} lines"
        elif isinstance(tool_response, dict) and tool_response.get("error"):
            result_line = f"FAILURE: {str(tool_response.get('error'))[:80]}"
        else:
            result_line = "SUCCESS"
    elif tool_name == "Task":
        # Agent tasks - show result summary
        if isinstance(tool_response, dict):
            result = tool_response.get("result", "")[:80]
            result_line = f"SUCCESS: {result}" if result else "SUCCESS"
        else:
            result_line = f"SUCCESS: {str(tool_response)[:80]}"
    else:
        # Generic handling
        result_line = f"SUCCESS: {str(tool_response)[:80]}"

    # Check file size and truncate if needed
    if log_path.exists() and log_path.stat().st_size > MAX_LOG_SIZE:
        _truncate_log(log_path)

    # Append entries
    try:
        with open(log_path, "a") as f:
            f.write(f"{timestamp} | {tool_name:<8} | {action}\n")
            f.write(f"{timestamp} | RESULT   | {result_line}\n")
    except Exception:
        pass  # Don't fail the hook if logging fails


def _truncate_log(log_path: Path) -> None:
    """Keep last 500KB of log file."""
    try:
        content = log_path.read_text()
        # Keep last ~500KB
        truncated = content[-500000:]
        # Find first complete line
        first_newline = truncated.find('\n')
        if first_newline > 0:
            truncated = truncated[first_newline + 1:]
        log_path.write_text(f"[... truncated ...]\n{truncated}")
    except Exception:
        pass  # Don't fail if truncation fails


def main():
    try:
        # Read JSON input from stdin
        input_data = json.load(sys.stdin)

        # Extract session_id
        session_id = input_data.get('session_id', 'unknown')

        # Add ADW context to logged data
        adw_context = get_adw_context()
        input_data["adw_id"] = adw_context.get("adw_id")
        input_data["issue_id"] = adw_context.get("issue_id")
        input_data["phase"] = adw_context.get("phase")

        # Ensure session log directory exists
        log_dir = ensure_session_log_dir(session_id)
        log_path = log_dir / 'post_tool_use.json'

        # Read existing log data or initialize empty list
        if log_path.exists():
            with open(log_path, 'r') as f:
                try:
                    log_data = json.load(f)
                except (json.JSONDecodeError, ValueError):
                    log_data = []
        else:
            log_data = []

        # Append new data
        log_data.append(input_data)

        # Write back to file with formatting
        with open(log_path, 'w') as f:
            json.dump(log_data, f, indent=2)

        # Also append to human-readable commands.log
        append_to_commands_log(log_dir, input_data)

        sys.exit(0)

    except json.JSONDecodeError:
        # Handle JSON decode errors gracefully
        sys.exit(0)
    except Exception:
        # Exit cleanly on any other error
        sys.exit(0)

if __name__ == '__main__':
    main()