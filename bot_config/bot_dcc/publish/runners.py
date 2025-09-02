from importlib import import_module
from pathlib import Path
from typing import List
from .api import Step, PublishError


def load_steps(package: str, subpkg: str) -> List[Step]:
    steps: List[Step] = []
    base = f"{package}.hooks.{subpkg}"
    pkg_path = Path(import_module(package).__file__).parent / "hooks" / subpkg
    if not pkg_path.exists():
        return steps
    for py in sorted(pkg_path.glob("*.py")):
        mod = import_module(f"{base}.{py.stem}")
        # convention: module exposes `STEP` instance
        step = getattr(mod, "STEP", None)
        if step:
            steps.append(step)
    return sorted(steps, key=lambda s: getattr(s, "order", 50))


def run_pipeline(package: str, context) -> None:
    for group in ("collectors", "validators", "extractors", "integrators"):
        for step in load_steps(package, group):
            step.process(context)
