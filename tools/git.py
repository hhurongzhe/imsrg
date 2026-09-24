import subprocess
from pathlib import Path

# * This script is used to commit changes to a git repository.
message = "my personal update"


repo = Path(__file__).resolve().parent.parent
branch = subprocess.run(
    ["git", "symbolic-ref", "--quiet", "--short", "HEAD"],
    cwd=repo, capture_output=True, text=True, check=True,
).stdout.strip()
commands = [["git", "add", "."], ["git", "commit", "-m", message], ["git", "pull", "--rebase", "origin", branch], ["git", "push", "origin", branch]]
for cmd in commands:
    result = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error executing: {' '.join(cmd)}")
        print(result.stderr)
        raise SystemExit(result.returncode)
    print(result.stdout.strip())
