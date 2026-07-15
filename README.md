# Universe Deliver 2D

Independent 2D version prototype of Universe Deliver.

This repository is intentionally separate from the original 3D Unreal project so the 2D direction can evolve with a lighter structure while preserving the 3D project's history in `/Users/dionysus/proj/universe_deliver`.

## Run locally

Use Godot `4.7.1-stable`. If Godot is not available on `PATH`, set its executable path first:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
```

From the repository root:

```bash
# Open the editor
"${GODOT_BIN:-godot}" --editor --path .

# Run import, parsing, tests, and whitespace checks
./scripts/check_project.sh

# Run the current main scene
"${GODOT_BIN:-godot}" --path .
```

The check script tries `GODOT_BIN`, `godot`, `godot4`, and the default macOS application path in that order.
