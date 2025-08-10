# CONTINUE.md

This is the contents of the CONTINUE.md file.

## Overview

This document provides an in-depth explanation of the Dockerfile used to build a containerized environment for vLLM (vulnerability and License Loss Modeling).

## Environment Variables

The Dockerfile uses several environment variables to configure the container's behavior:

*   `DEBIAN_FRONTEND`: Set to `noninteractive` to speed up package installation.
*   `PYTHONUNBUFFERED`: Set to 1 to enable unbuffered output, useful for debugging.
*   `CUDA_HOME` and `PATH`: Set to use CUDA 12.4.0 runtime on Ubuntu 22.04.
*   `LD_LIBRARY_PATH`: Set to include the CUDA library path.
*   `PIP_NO_CACHE_DIR` and `PIP_DISABLE_PIP_VERSION_CHECK`: Used for pip optimizations.

## System Dependencies

The Dockerfile installs system dependencies required for pyenv and nginx:

*   Packages: `make`, `build-essential`, `libssl-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `wget`, `curl`, `llvm`, `libncurses5-dev`, `libncursesw5-dev`, `xz-utils`, `tk-dev`, `libffi-dev`, `liblzma-dev`.
*   `git` for cloning the pyenv repository.
*   `nginx` and `supervisor` for runtime environments.

## Pyenv Installation

The Dockerfile clones the pyenv repository and sets environment variables for pyenv:

*   Clones the pyenv repository to `/opt/pyenv`.
*   Sets `PYENV_ROOT` and `PATH` environment variables.
*   Initializes pyenv in the shell with `eval "$(pyenv init -)"`.

## Python Installation

The Dockerfile installs Python 3.12 using pyenv:

*   Installs Python 3.12 via pyenv.
*   Sets up symbolic links for Python 3.12 and pip.

## Pip Upgrade and uv Installation

The Dockerfile upgrades pip and installs uv first using the pyenv Python:

*   Upgrades pip.
*   Installs uv with CUDA support.

## vLLM Installation

The Dockerfile installs vLLM, related dependencies, and PyTorch with CUDA support:

*   Installs `uv` in the virtual environment.
*   Installs vLLM (GPT-OSS) with additional dependencies (`transformers`, `accelerate`, `safetensors`, `numpy`, `pyyaml`, `uvicorn`, `fastapi`) from wheels.

## nginx Runtime

The Dockerfile prepares nginx runtime directories and exposes ports for vLLM instances:

*   Creates working directory `/app`.
*   Exposes ports 8000-8010 (for dynamic vLLM instances) and 80.
*   Copies scripts to the container and makes them executable.

## Default Command

The Dockerfile sets the default command to launch a dynamic vLLM + nginx orchestrator:

*   Uses `python` as the interpreter.
*   Runs `/app/scripts/vllm_launcher.py`.