#!/bin/bash
PATH="/opt/bin:/opt/sbin:$PATH"
export qnapDir="/share/MD0_DATA/backup"
ln -sf /share/MD0_DATA/btsync/zshrc-simple ~/.zshrc
ln -sf /share/MD0_DATA/btsync/vimrc-simple ~/.vimrc
zsh
