#!/bin/bash

set -e

if [ ! -d "opseng-challenge-app" ]; then
    git clone --quiet https://github.com/wvchallenges/opseng-challenge-app.git
fi

cd opseng-challenge-app
git fetch

if [ ! -z "$1" ] && [ "$1" != "HEAD" ] ; then
    revision=${1:0:7}
else
    revision=`git rev-parse --short HEAD`
    echo "Using revision HEAD ($revision)"
fi

if [ "$2" == "-production" ]
then
    namespace="production"
else
    namespace="staging"
fi

if [ `docker images "joonathanwaveexample/opseng-challenge-app:$revision" -q | wc -l` -gt 0 ] ; then
    echo "Using $revision for deployment"

    if [ ! -f "/home/ubuntu/.docker/config.json" ]; then
        mkdir -p /home/ubuntu/.docker/
        gpg --yes --passphrase=$AWS_SECRET_ACCESS_KEY --decrypt -o /home/ubuntu/.docker/config.json ~/application/config-${AWS_ACCESS_KEY_ID:0:6}.json.gpg
    fi

    echo Starting Docker push
    docker push joonathanwaveexample/opseng-challenge-app:`git rev-parse --short HEAD` >/dev/null

    echo Docker image of revision $revision pushed as joonathanwaveexample/opseng-challenge-app:`git rev-parse --short HEAD`

    cp ~/application/opseng-challenge-app.deployment.yaml .
    export revision=$revision
    envsubst '$revision' < opseng-challenge-app.deployment.yaml > $revision-opseng-challenge-app.deployment.yaml
    kubectl apply -f $revision-opseng-challenge-app.deployment.yaml --namespace=$namespace
    echo "Deployment rollout to $namespace environment initiated"
else   
    echo "Docker image for that revision not found, use one of the following revisions:"
    docker images "joonathanwaveexample/opseng-challenge-app"
    exit 1
fi
