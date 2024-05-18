#!/bin/bash

set -xeo pipefail

# create cover directory

cover_dir="${GITHUB_WORKSPACE}/go-cover/./${INPUTS_PATH}"
mkdir -p "${cover_dir}/revisions"
mkdir -p "${cover_dir}/head"

cd "${INPUTS_PATH}"

# generate coverage files

go tool cover -html=cover.out -o "${cover_dir}/revisions/${REVISION}.html"
go tool cover -func=cover.out -o "${cover_dir}/revisions/${REVISION}.txt"
cp cover.out                     "${cover_dir}/revisions/${REVISION}.out"

# generate incremental coverage files

echo "mode: set" > incremental.out
# grep exits with 1 if no lines are found, so we need to ignore that
grep -F -v -x -f "${cover_dir}/head/head.out" cover.out >> incremental.out || true
go tool cover -html=incremental.out -o "${cover_dir}/revisions/${REVISION}-inc.html"
go tool cover -func=incremental.out -o "${cover_dir}/revisions/${REVISION}-inc.txt"
cp incremental.out                     "${cover_dir}/revisions/${REVISION}-inc.out"

cd "${cover_dir}"

# copy assets

cp "${GITHUB_ACTION_PATH}"/assets/* .

# beautify html

# this is useful for browser caching
hash=$(cat index.css index.js | md5sum | awk '{print $1}')

for file in "revisions/${REVISION}.html" "revisions/${REVISION}-inc.html"; do
  ex -sc '%s/\n\t\t<style>\_.\{-}<\/style>//' -c 'x' "${file}"
  ex -sc '%s/\n\t<script>\_.\{-}<\/script>//' -c 'x' "${file}"
  ex -sc '%s/<title>/<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" \/>\r\t\t<title>/' -c 'x' "${file}"
  ex -sc '%s/<title>/<meta http-equiv="Pragma" content="no-cache" \/>\r\t\t<title>/' -c 'x' "${file}"
  ex -sc '%s/<title>/<meta http-equiv="Expires" content="0" \/>\r\t\t<title>/' -c 'x' "${file}"
  ex -sc '%s/<\/title>/<\/title>\r\t\t<script src="..\/index.js?'"${hash}"'"><\/script>/' -c 'x' "${file}"
done

# if we are on the main branch, copy files to main.*

if [ "${REF_NAME}" = "main" ]; then
  cp "revisions/${REVISION}.html" "${cover_dir}/head/head.html"
  cp "revisions/${REVISION}.txt"  "${cover_dir}/head/head.txt"
  cp "revisions/${REVISION}.out"  "${cover_dir}/head/head.out"
fi

# push to branch

git add .
git config user.email "go-coverage-action@github.com"
git config user.name "go-coverage-action"

# quick way to continue when there is nothing to commit
# TODO: find a better way to handle this and not mask actual errors
git commit -m "chore: add cover for ${REVISION}" || true

git push origin "${INPUTS_BRANCH}"