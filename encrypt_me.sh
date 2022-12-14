#!/bin/bash
sops -e $1 | tee $1.encrypted
