#!/usr/bin/env bash
# File: scripts/init_natron_publish_scaffold.sh
# Purpose: Create a Natron-based publish pipeline scaffold (ShotGrid-style) without overwriting existing files.

set -euo pipefail

PROJECT="SHOW"
PUBLISH_ROOT="/projects/${PROJECT}/publish"
WORK_ROOT="/projects/${PROJECT}/work"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)       PROJECT="$2"; shift 2 ;;
    --publish-root)  PUBLISH_ROOT="$2"; shift 2 ;;
    --work-root)     WORK_ROOT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --project MEGA --publish-root /projects/MEGA/publish --work-root /projects/MEGA/work"
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

announce () { printf "• %s\n" "$1"; }

make_dir () {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    mkdir -p "$d"
    announce "mkdir  $d"
  fi
}

make_file () {
  local f="$1"; shift
  local content="$*"
  if [[ ! -f "$f" ]]; then
    mkdir -p "$(dirname "$f")"
    printf "%s" "$content" > "$f"
    announce "create $f"
  else
    announce "skip   $f (exists)"
  fi
}

PY_INIT=$'"""Package."""\n'

# 1) Directory layout ----------------------------------------------------------
make_dir "bot_config/bot_common"
make_dir "bot_config/bot_config"
make_dir "bot_config/bot_dcc/publish"
make_dir "bot_config/bot_dispatcher"
make_dir "bot_config/bot_folder_structure"
make_dir "bot_config/bot_shows/${PROJECT}"
make_dir "bot_config/packager"
make_dir "bot_config/bot_natron/hooks/collectors"
make_dir "bot_config/bot_natron/hooks/validators"
make_dir "bot_config/bot_natron/hooks/extractors"
make_dir "bot_config/bot_natron/hooks/integrators"
make_dir "scripts"

# 2) Common utils --------------------------------------------------------------
make_file "bot_config/bot_common/__init__.py" "$PY_INIT"

make_file "bot_config/bot_common/logging_utils.py" $'import logging\n\n\ndef get_logger(name: str = "pipeline") -> logging.Logger:\n    logger = logging.getLogger(name)\n    if not logger.handlers:\n        h = logging.StreamHandler()\n        f = logging.Formatter("[%(levelname)s] %(name)s: %(message)s")\n        h.setFormatter(f)\n        logger.addHandler(h)\n        logger.setLevel(logging.INFO)\n    return logger\n'

make_file "bot_config/bot_common/fs.py" $'from pathlib import Path\nimport hashlib\n\n\ndef ensure_dir(p: str | Path) -> Path:\n    p = Path(p)\n    p.mkdir(parents=True, exist_ok=True)\n    return p\n\n\ndef md5sum(p: str | Path) -> str:\n    m = hashlib.md5()\n    with open(p, "rb") as f:\n        for chunk in iter(lambda: f.read(8192), b""):\n            m.update(chunk)\n    return m.hexdigest()\n'

# 3) Config + templates --------------------------------------------------------
make_file "bot_config/bot_config/__init__.py" "$PY_INIT"

make_file "bot_config/bot_folder_structure/templates.yml" $'publish_root: "'$PUBLISH_ROOT$'"\nwork_root: "'$WORK_ROOT$'"\n\nnuke_script: "{work_root}/shots/{seq}/{shot}/natron/{task}/{shot}_{task}_v{version:03}.ntp"\nrender_dir:  "{publish_root}/shots/{seq}/{shot}/comp/{task}/v{version:03}/"\nreview_mov:  "{publish_root}/shots/{seq}/{shot}/review/comp/{shot}_v{version:03}.mp4"\nthumbnail:   "{publish_root}/shots/{seq}/{shot}/thumbs/{shot}_v{version:03}.jpg"\n'

make_file "bot_config/bot_shows/${PROJECT}/project.yml" $'code: "'$PROJECT$'"\nfps: 24\nresolution: [1920, 1080]\ncolorspace: "sRGB"\n'

# 4) DCC-agnostic publish core -------------------------------------------------
make_file "bot_config/bot_dcc/__init__.py" "$PY_INIT"

make_file "bot_config/bot_dcc/publish/__init__.py" "$PY_INIT"

make_file "bot_config/bot_dcc/publish/schema.py" $'from dataclasses import dataclass, field\nfrom typing import List, Dict\n\n@dataclass\nclass Representation:\n    name: str\n    path: str\n    ext: str | None = None\n    md5: str | None = None\n    size: int | None = None\n\n@dataclass\nclass PublishContext:\n    project: str\n    seq: str\n    shot: str\n    task: str\n    version: int\n    user: str\n    fps: float\n    resolution: tuple[int, int]\n    data: Dict = field(default_factory=dict)\n    representations: List[Representation] = field(default_factory=list)\n'

make_file "bot_config/bot_dcc/publish/api.py" $'class PublishError(Exception):\n    pass\n\nclass Step:\n    label = "Step"\n    order = 50\n    def process(self, context):\n        raise NotImplementedError\n\nclass Collector(Step):\n    label = "Collector"\n\nclass Validator(Step):\n    label = "Validator"\n\nclass Extractor(Step):\n    label = "Extractor"\n\nclass Integrator(Step):\n    label = "Integrator"\n'

make_file "bot_config/bot_dcc/publish/runners.py" $'from importlib import import_module\nfrom pathlib import Path\nfrom typing import List\nfrom .api import Step, PublishError\n\n\ndef load_steps(package: str, subpkg: str) -> List[Step]:\n    steps: List[Step] = []\n    base = f\"{package}.hooks.{subpkg}\"\n    pkg_path = Path(import_module(package).__file__).parent / "hooks" / subpkg\n    if not pkg_path.exists():\n        return steps\n    for py in sorted(pkg_path.glob("*.py")):\n        mod = import_module(f\"{base}.{py.stem}\")\n        # convention: module exposes `STEP` instance\n        step = getattr(mod, "STEP", None)\n        if step:\n            steps.append(step)\n    return sorted(steps, key=lambda s: getattr(s, "order", 50))\n\n\ndef run_pipeline(package: str, context) -> None:\n    for group in (\"collectors\", \"validators\", \"extractors\", \"integrators\"):\n        for step in load_steps(package, group):\n            step.process(context)\n'

# 5) Natron a
