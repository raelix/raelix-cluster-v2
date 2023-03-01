#!/bin/bash
export SOPS_AGE_KEY_FILE=${2:-~/.config/sops/age/keys.txt}

sops --decrypt "$1"
