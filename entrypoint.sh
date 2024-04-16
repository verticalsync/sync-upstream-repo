#!/usr/bin/env bash

set -x

UPSTREAM_REPO=$1
UPSTREAM_BRANCH=$2
DOWNSTREAM_BRANCH=$3
GITHUB_TOKEN=$4
FETCH_ARGS=$5
MERGE_ARGS=$6
PUSH_ARGS=$7

if [[ -z "$UPSTREAM_REPO" ]]; then
  echo "Missing \$UPSTREAM_REPO"
  exit 1
fi

if [[ -z "$DOWNSTREAM_BRANCH" ]]; then
  echo "Missing \$DOWNSTREAM_BRANCH"
  echo "Default to ${UPSTREAM_BRANCH}"
  DOWNSTREAM_BRANCH=$UPSTREAM_BRANCH
fi

if ! echo "$UPSTREAM_REPO" | grep '\.git'; then
  UPSTREAM_REPO="https://github.com/${UPSTREAM_REPO_PATH}.git"
fi

echo "UPSTREAM_REPO=$UPSTREAM_REPO"

git clone "https://github.com/${GITHUB_REPOSITORY}.git" work
cd work || { echo "Missing work dir" && exit 2 ; }

git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --local user.password ${GITHUB_TOKEN}
git config checkout.defaultRemote origin

git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

git remote add upstream "$UPSTREAM_REPO"
git fetch ${FETCH_ARGS} upstream
git remote -v

git checkout ${DOWNSTREAM_BRANCH}

git push origin

MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/${UPSTREAM_BRANCH})

echo -e '# Summary\n' > $GITHUB_STEP_SUMMARY

if git diff --name-only --diff-filter=U | grep -q .; then
  echo "## There are conflicts in the merge. Please resolve them." >> $GITHUB_STEP_SUMMARY
  exit 1
fi

if [[ $MERGE_RESULT == "" ]]; then
  echo "## Merge failed: $MERGE_RESULT" >> $GITHUB_STEP_SUMMARY
  exit 1
elif [[ $MERGE_RESULT == *"Already up to date." ]]; then
  echo "## Everything is already up to date." >> $GITHUB_STEP_SUMMARY
elif [[ $MERGE_RESULT != *"Already up to date." ]]; then
  git commit -m "Merged upstream"
  git push ${PUSH_ARGS} origin ${DOWNSTREAM_BRANCH} || exit $?
  echo "## Merged everything successfully" >> $GITHUB_STEP_SUMMARY
fi
