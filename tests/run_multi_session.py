"""Exercise real debugger sessions in a temporary Godot project (Python 3.9+)."""
import argparse
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile


def pick_debug_uri():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    return f"tcp://127.0.0.1:{port}"


def run_attempt(godot, repo, uri):
    # Keep generated files outside the addon and repository under test.
    with tempfile.TemporaryDirectory(prefix="copy-all-errors-test-") as directory:
        project = Path(directory)
        fixtures = repo / "tests/multi_session"
        for name in ("project.godot", "main.tscn", "actor.gd"):
            shutil.copy2(fixtures / name, project / name)
        addon = project / "addons/copy_all_errors"
        shutil.copytree(repo / "addons/copy_all_errors", addon, ignore=shutil.ignore_patterns("*.uid"))
        shutil.copy2(fixtures / "recording_plugin.gd", addon / "recording_plugin.gd")
        config = addon / "plugin.cfg"
        config.write_text(config.read_text(encoding="utf-8").replace('script="plugin.gd"', 'script="recording_plugin.gd"'), encoding="utf-8")
        probe = project / "addons/regression"
        probe.mkdir()
        shutil.copy2(fixtures / "regression.gd", probe / "plugin.gd")
        (probe / "plugin.cfg").write_text('[plugin]\nname="Multi-session regression"\ndescription=""\nauthor=""\nversion="1"\nscript="plugin.gd"\n', encoding="utf-8")
        command = [godot, "--headless", "--editor", "--path", str(project), "--debug-server", uri, "--", uri]
        # The fixture terminates its clients on completion; the deadline also
        # catches parser/startup failures which cannot execute the fixture.
        with (project / "process.log").open("wb") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        output = (project / "process.log").read_text(encoding="utf-8", errors="replace")
        return result.returncode, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Path to a Godot editor executable")
    parser.add_argument("--log", type=Path, help="Optional path for the final attempt's process log")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    for attempt in range(3):
        code, output = run_attempt(args.godot, repo, pick_debug_uri())
        # Exit 75 is reserved for initial connection failure, before exercising
        # plugin behavior. Never retry an assertion failure to hide a regression.
        if code != 75 or attempt == 2:
            break
        print("Debugger startup failed; retrying with a new port.", flush=True)
    if args.log:
        args.log.write_text(output, encoding="utf-8")
    print("\n".join(line for line in output.splitlines() if "MULTI_SESSION" in line))
    if code or "MULTI_SESSION_PASS" not in output or "ERROR:" in output:
        raise SystemExit(output)


if __name__ == "__main__":
    main()
