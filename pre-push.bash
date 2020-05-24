#!/usr/bin/env bash

project_root="$( git rev-parse --show-toplevel )"
pushd "${project_root}" &> /dev/null || exit 1
make &> /dev/null
num_diff_files="$( git diff --name-only | wc -l )"
num_untracked_files="$( git ls-files --others --exclude-standard | wc -l )"
if [ "${num_diff_files}" != "0" ] || [ "${num_untracked_files}" != "0" ] ; then
  echo "diff detected after running \`make\`, not pushing"
  exit 1
fi
popd &> /dev/null || exit 1
