#!/usr/bin/env bash

set -x

UPSTREAM_REPO=$1
UPSTREAM_BRANCH=$2
DOWNSTREAM_BRANCH=$3
GITHUB_TOKEN=$4
FETCH_ARGS=$5
MERGE_ARGS=$6
PUSH_ARGS=$7
SPAWN_LOGS=$8

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

case ${SPAWN_LOGS} in
  (true)    echo -n "sync-upstream-repo https://github.com/dabreadman/sync-upstream-repo keeping CI alive."\
            "UNIX Time: " >> sync-upstream-repo
            date +"%s" >> sync-upstream-repo
            git add sync-upstream-repo
            git commit sync-upstream-repo -m "Syncing upstream";;
  (false)   echo "Not spawning time logs"
esac

git push origin

MERGE_RESULT=$(git merge ${MERGE_ARGS} upstream/${UPSTREAM_BRANCH})


if [[ $MERGE_RESULT == "" ]]; then
  echo "::set-output name=result::Merge failed: $MERGE_RESULT"
  exit 1
elif [[ $MERGE_RESULT != *"Already up to date." ]]; then
  git commit -m "Merged upstream"
  git push ${PUSH_ARGS} origin ${DOWNSTREAM_BRANCH} || exit $?
  echo "Merged everything successfully"
  echo "::set-output name=result::Merged everything successfully"
elif [[ $MERGE_RESULT == *"Already up to date." ]]; then
  echo "Everything is already up to date."
  echo "::set-output name=result::Everything is already up to date"
else
  if git diff --name-only --diff-filter=U | grep -q .; then
    echo "There are conflicts in the merge. Please resolve them."
    echo "::set-output name=result::Merge failed: Conflicts in merge"
    exit 1
  fi
  
  echo "Unknown merge result, please check above for any issues."
  echo "::set-output name=result::Merge failed: Unknown result"
  exit 1
fi

cd ..
rm -rf work
