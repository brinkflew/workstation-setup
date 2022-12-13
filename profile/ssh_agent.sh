#!/bin/sh

# ==============================================================================
# This script loads declared SSH keys into the running ssh-agent, launching it
# if necessary. This should ideally be sourced in the user's shell profile.
# ==============================================================================

env=~/.ssh/agent.env

# --- Declare the path to the keys to add to the agent -------------------------
declare -a keys=(
  "$HOME/.ssh/id_ed25519"
)

# --- Common methods and shortcuts ---------------------------------------------

agent_load_env() {
  test -f "$env" && . "$env" >| /dev/null
}

agent_start() {
  (umask 077; ssh-agent >| "$env")
  . "$env" >| /dev/null 2>&1
}

agent_add_key() {
  ssh-add $key >| /dev/null 2>&1
}

agent_add_keys() {
  for i in "${keys[@]}"; do
    ssh-add "$i" >| /dev/null 2>&1
  done
}

# --- Load the agent -----------------------------------------------------------

agent_load_env

# agent_run_state:
#   0: agent running with key
#   1: agent running without key
#   2: agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

# --- Load the keys to the agent -----------------------------------------------

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
  agent_start
  agent_add_keys
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
  agent_add_keys
fi

unset env
