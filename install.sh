#!/bin/bash
set -euo pipefail

# =============================================================================
# First clone the ARENA_3.0 repo using:
#   git clone https://github.com/callummcdougall/ARENA_3.0.git
# Then, usage (must be run with bash, not sh):
#   bash ARENA_3.0/install.sh                        # RunPod (default), with llm-context repo
#   bash ARENA_3.0/install.sh --platform vastai      # Vast.ai platform
#   bash ARENA_3.0/install.sh --no-llm-context       # Skip cloning arena-llm-context
#
# The script can be run from any working directory - it locates the repo relative
# to its own path.
# =============================================================================

# Defaults
PLATFORM="runpod"
CONDA_ENV="arena-env"
PYTHON_VERSION="3.11"
CLONE_LLM_CONTEXT=true

# Locate the repo (the directory containing this script) and its parent
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$REPO_DIR")"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --no-llm-context) CLONE_LLM_CONTEXT=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Setup: platform=$PLATFORM, repo=$REPO_DIR, clone_llm_context=$CLONE_LLM_CONTEXT ==="

# --- Install Miniconda (skip if already present) ---
if [ -x "$HOME/miniconda3/bin/conda" ]; then
    echo "=== Miniconda already installed at $HOME/miniconda3, skipping ==="
else
    echo "=== Installing Miniconda ==="
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm -rf ~/miniconda3/miniconda.sh
fi
~/miniconda3/bin/conda init bash

# Source conda.sh to get conda activate working in this script
source ~/miniconda3/etc/profile.d/conda.sh

# --- Accept conda TOS ---
echo "=== Accepting Conda TOS ==="
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# --- Create and activate conda env ---
echo "=== Creating conda env '$CONDA_ENV' (python $PYTHON_VERSION) ==="
conda create -n "$CONDA_ENV" python="$PYTHON_VERSION" -y
conda activate "$CONDA_ENV"
echo "=== Active Python: $(which python) ==="

# --- Install git ---
echo "=== Installing system packages ==="
if [[ "$PLATFORM" == "runpod" ]]; then
    apt update && apt install -y git curl
elif [[ "$PLATFORM" == "vastai" ]]; then
    sudo apt update && sudo apt install -y git
fi

# Maybe clone the repo which gives you extra context for LLMs (to help with exercises)
if $CLONE_LLM_CONTEXT; then
    REPO="callummcdougall/arena-llm-context"
    BRANCH="main"
    if [ -d "$PARENT_DIR/arena-llm-context" ]; then
        echo "=== $PARENT_DIR/arena-llm-context already exists, skipping clone ==="
    else
        echo "=== Cloning $REPO (branch: $BRANCH) into $PARENT_DIR ==="
        git clone -b "$BRANCH" "https://github.com/${REPO}.git" "$PARENT_DIR/arena-llm-context"
    fi
fi

# # --- Git config ---
# git config --global user.name callummcdougall
# git config --global user.email cal.s.mcdougall@gmail.com

# --- Install Python deps ---
echo "=== Installing Python dependencies from $REPO_DIR ==="
cd "$REPO_DIR"
pip install -U pip setuptools wheel
pip install -r requirements.txt
conda install -n "$CONDA_ENV" ipykernel --update-deps --force-reinstall -y

# --- Register the env as a Jupyter kernel ---
echo "=== Registering Jupyter kernel '$CONDA_ENV' ==="
python -m ipykernel install --user --name "$CONDA_ENV" --display-name "ARENA ($CONDA_ENV)"

# --- VS Code workspace settings ---
echo "=== Configuring VS Code workspace settings ==="

mkdir -p "$HOME/.vscode"
cat > "$HOME/.vscode/settings.json" << EOF
{
    "python.defaultInterpreterPath": "$HOME/miniconda3/envs/$CONDA_ENV/bin/python",
    "python.analysis.extraPaths": [
        "$REPO_DIR/chapter0_fundamentals/exercises",
        "$REPO_DIR/chapter1_transformer_interp/exercises",
        "$REPO_DIR/chapter2_rl/exercises",
        "$REPO_DIR/chapter3_llm_evals/exercises",
        "$REPO_DIR/chapter4_alignment_science/exercises"
    ]
}
EOF

echo "=== Done! ==="
echo
echo "Run 'conda activate $CONDA_ENV' in new shells (or open a new terminal)."
echo "Verify the GPU with:"
echo "  python -c \"import torch; print(torch.__version__, torch.cuda.is_available())\""
echo
echo "For the [2.3] MuJoCo GPU (Brax) section only, additionally run:"
echo "  pip install -r $REPO_DIR/requirements-mujoco-gpu.txt"
