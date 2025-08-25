# Bot Project Monorepo – Design Overview

This document explains the structure and design of the uploaded project based on the extracted folder tree.

## Big Picture
- Multiple Python packages, each with its own `setup.py`, `requirements.txt`, tests, and `src/<package>` layout → meant to be installed independently and versioned/published if needed.  
- A **shared utilities/core** package (`bot_common`) other packages depend on. It exposes `constants.py`, `context.py`, `utils.py`, and a `yaml_resolver.py` for config loading.
- A **configuration** package (`bot_config`) wrapping config files/logic (`config.py`, `constants.py`, exceptions) → central place to read and validate settings.
- A **DCC abstraction** layer (`bot_dcc`) with `dcc.py` and a `template.py` → generic integration layer for Digital Content Creation apps (Maya/Blender/Houdini/etc.), so downstream bots can share a uniform interface.
- A **dispatcher** package (`bot_dispatcher`) with a `dispatcher.py` → likely the orchestrator/entry point that routes work to the right bot(s) or DCC backend.
- A **Nuke-specific bot** (`bot_nuke`) with `bot_nuke.py` → concrete implementation for Foundry Nuke built on the common + DCC layers.
- A **shows/project helper** (`bot_shows`) exposing `utils.py` and `constants.py` → helpers for show/shot/asset naming, paths, etc.
- A **packaging CLI** (`packager`) with `cli.py`, `__main__.py`, and `packager.py` → a command‑line tool to bundle/deploy these bots (e.g., zip/wheels/site packages).
- A **reference folder scaffold** (`bot_folder_structure/root/…`) with `clients/`, `shows/`, and `site/` → a template for how production storage should be organized.
- Most packages include `dev-requirements.txt` and `dodo.py` (doit) → repeatable dev tasks (lint, test, build).

## Layering and Flow
1. **bot_common** — foundation: constants, error types, context objects (e.g., current show/shot/user), and YAML config resolution. Other packages import from here.  
2. **bot_config** — configuration API: load/validate config (env + YAML) and expose a clean interface to consumers.  
3. **bot_dcc** — DCC abstraction: defines a common interface (`dcc.py`, plus templates) so concrete bots can run inside various DCC apps consistently.  
4. **bot_nuke** — concrete bot: implements Nuke behaviors using the DCC + common layers.  
5. **bot_shows** — show/site helpers: utilities and constants around show directory structure, slates, naming, etc.  
6. **bot_dispatcher** — orchestration: a single `dispatcher.py` that probably parses a command/context and hands it to the right bot/DCC backend.  
7. **packager** — distribution tool: CLI/`__main__` suggests you can run `python -m packager` or `packager ...` to build artifacts for deployment.  
8. **bot_folder_structure** — opinionated filesystem layout for clients/shows/site, useful for bootstrap scripts or validation.

## What You Can Do
- **Develop locally**:  
  ```bash
  python -m venv .venv && source .venv/bin/activate
  pip install -e ./bot_common ./bot_config ./bot_dcc ./bot_dispatcher ./bot_shows ./bot_nuke ./packager
  ```
- **Run tests**: most packages have `tests/` with unit tests (e.g., `test_bot_context.py`, `test_yaml_resolver.py`, `test_packager.py`).
- **Try the packager**:  
  ```bash
  python -m packager --help
  ```
- **Adopt the folder scaffold**: mirror `bot_folder_structure/root` to your studio share or project drive as a starting layout.

## Why This Structure Works Well
- Clear **separation of concerns**: shared core vs. config vs. DCC abstraction vs. app‑specific bots.
- Easy **testing & packaging**: each module is pip‑installable, testable, and releasable.
- **Dispatcher** pattern encourages plug‑and‑play: new DCCs/bots can be added without touching the core layers.
- **Scaffolded filesystem** reduces chaos across shows/clients.

---

You can extend this by:
- Drawing a diagram of the data flow (Context → Dispatcher → DCC → Bot).
- Creating a minimal “Hello, Nuke bot” that loads config and runs through the dispatcher.
