#!/bin/bash

if [ -d "opseng-challenge-app" ]; then
    rm -rf opseng-challenge-app
fi

git clone --quiet https://github.com/wvchallenges/opseng-challenge-app.git

cp .dockerignore opseng-challenge-app
cp Dockerfile opseng-challenge-app

cd opseng-challenge-app

revision=${1:-HEAD}
git checkout $revision >/dev/null || exit 1
echo "Checked out revision $revision"

echo "Starting Docker build"
docker build --rm=true -t "joonathanwaveexample/opseng-challenge-app:"`git rev-parse --short HEAD` .
