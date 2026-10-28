# Point this Nix install's update check at the stable channel, like Tier 1.
# Run by home-module.nix with the Python of the package's venv:
#   python3 -I stable-channel.py $HERMES_HOME/config.yaml
# Hermes keys the record on its install root (the venv's site-packages), a
# store path that changes with every version, and refuses `hermes update
# --set-channel` on Nix, so the record is written here at each activation.
import sys
from pathlib import Path

from hermes_cli.config import get_project_root
from hermes_cli.update_channel import install_id
from ruamel.yaml import YAML

config_path = Path(sys.argv[1])
# Same root as hermes_cli.source_check.check_for_updates.
root = Path(get_project_root()).resolve()

yaml = YAML()  # round-trip: keeps comments and key order
yaml.width = 4096  # no folded store paths
config = (yaml.load(config_path) if config_path.exists() else None) or {}
installs = config.setdefault("update", {}).setdefault("installs", {})
# Drop the records of earlier Nix store paths.
for key in [k for k, v in installs.items() if isinstance(v, dict) and str(v.get("path", "")).startswith("/nix/store/")]:
    del installs[key]
installs[install_id(root)] = {"path": str(root), "channel": "stable"}
yaml.dump(config, config_path)
