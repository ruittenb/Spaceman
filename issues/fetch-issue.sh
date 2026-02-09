#!/usr/bin/env bash

owner=ruittenb
repo=spaceman

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <issue1> [ <issue2> ... ]" >&2
    exit 1
fi

for issue in "$@"; do
    echo "Fetching issue $issue"
    curl -s "https://api.github.com/repos/$owner/$repo/issues/$issue" > "issue-$issue".json
    curl -s "https://api.github.com/repos/$owner/$repo/issues/$issue/comments" > "issue-$issue-comments".json
done

