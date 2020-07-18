#!/bin/bash

base_branch="develop"

if [ "$1" != "" ]; then
  base_branch="$1"
fi

current_branch=`git rev-parse --abbrev-ref HEAD`

echo "Running Rubocop in branch $current_branch against $base_branch"

changed_files=`git diff --name-only $current_branch $(git merge-base $current_branch $base_branch) | grep '\.rb'`

rubocop_command=""

for file in $changed_files; do
  rubocop_command="$rubocop_command $file"
done

if [ "$rubocop_command" != "" ]; then
  echo "Running Rubocop on $changed_files"
  bundle exec rubocop $rubocop_command
else
  echo "No files changed"
fi
