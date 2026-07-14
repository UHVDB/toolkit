#!/usr/bin/env bash

# Customise the terminal command prompt
echo "export PROMPT_DIRTRIM=2" >> $HOME/.bashrc
echo "export PS1='\[\e[3;36m\]\w ->\[\e[0m\\] '" >> $HOME/.bashrc
export PROMPT_DIRTRIM=2
export PS1='\[\e[3;36m\]\w ->\[\e[0m\\] '

# Update Nextflow
nextflow self-update

# Install micromamba if missing
if ! command -v micromamba >/dev/null 2>&1; then
  curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest | tar -xvj -C /usr/local bin/micromamba
fi
# Ensure non-interactive shells (Nextflow) can find it
ln -sf "$(command -v micromamba 2>/dev/null || echo /usr/local/bin/micromamba)" /usr/local/bin/micromamba

# Update welcome message
echo "Welcome to the UHVDB/toolkit devcontainer!" > /usr/local/etc/vscode-dev-containers/first-run-notice.txt
