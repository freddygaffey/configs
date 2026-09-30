#!/bin/sh
# tracker-miner-fs was indexing all of $HOME including ~600 GB of drone mission
# frames and decompilation corpora, and re-extracting one unreadable file for
# months. Small index, pointless CPU.
# Undo: gsettings reset org.freedesktop.Tracker3.Miner.Files index-recursive-directories
set -eu
gsettings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories \
  "['$HOME/Documents', '$HOME/Downloads']"
gsettings set org.freedesktop.Tracker3.Miner.Files index-single-directories "['$HOME']"
echo "done. rebuild the index with: tracker3 reset --filesystem"
