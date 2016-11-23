#!/bin/bash

set -e

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo -n "We require AWS_ACCESS_KEY_ID: "; read AWS_ACCESS_KEY_ID
    export AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo -n "We require AWS_SECRET_ACCESS_KEY: "; read AWS_SECRET_ACCESS_KEY
   export AWS_SECRET_ACCESS_KEY
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo "AWS credentials not provided. Exiting"
   exit 1
fi

if [ ! -f "joonathan-waveexample-bastion.pem" ]; then
    echo "You need to set up a new cluster"
    
    while true; do
        read -p "do you want to continue 'y' or 'n': " yn
        case $yn in

            [Yy]* )
                echo "Setting up Bastion host: ";
                ( ./bootstrap/bootstrap.sh )

                KUBERNETES_TOKEN=`python -c 'import random; import string; print "%0s.%0s" % ("".join(random.sample(string.lowercase+string.digits,6)), "".join(random.sample(string.lowercase+string.digits,16)))'`
                echo "export KUBERNETES_TOKEN=$KUBERNETES_TOKEN" >> output_variables.sh
                
                source output_variables.sh

                ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" TF_VAR_kubernetes_token="$KUBERNETES_TOKEN" TF_VAR_bastion_instance_ip="$BASTION_INSTANCE_IP"
cd ~/terraform/
terraform apply -var 'public_key_path=~/.ssh/id_rsa.pub' -var 'private_key_path=~/.ssh/id_rsa'
EOF

                ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
export KUBECONFIG="/home/ubuntu/.kubeconfig"
kubectl get nodes
kubectl create -f application/opseng-challenge-app.service.yaml --namespace staging
kubectl create -f application/opseng-challenge-app.service.yaml --namespace production
kubectl create -f application/opseng-challenge-app.staging.ingress.yaml --namespace staging
kubectl create -f application/opseng-challenge-app.production.ingress.yaml --namespace production
EOF

                break;;

            [Nn]* )
                exit;;

            * )
                echo "Please answer yes or no: ";;

        esac
    done
fi

echo "Looks like we might already have a cluster"
source output_variables.sh

while true; do
    echo "s) Build and deploy application to staging"
    echo "p) Deploy application to production"
    echo "q) Quit"
    read -p "please make your choise between 's', 'p' and 'q': " sp
    case $sp in

        [Ss]* )
            read -p "should we use any specific git commit hash? empty to use latest: " build
            if [ -z $build ]
            then
                build="HEAD"
                echo "Using HEAD"
            fi
            echo "Building and deploying to staging: ";

            ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
export KUBECONFIG="/home/ubuntu/.kubeconfig" AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" 
cd application
./build.sh $build
if ./deploy.sh $build -staging;
then
    kubectl get pods --namespace staging -l role=opseng-challenge-app
    echo "On deployment completion Challenge App will we available on https://staging.waveexample.site"
    echo "Checking for deployment completion..."
    until curl --output /dev/null --silent --head --fail https://staging.waveexample.site/; do
        kubectl get pods --namespace staging -l role=opseng-challenge-app
        echo "retrying required..."
        sleep 5
    done
    echo "Deployment completed, please visit https://staging.waveexample.site"
else
    echo "Deployment failed!"
fi
EOF

            break;;

        [Pp]* )
            echo "Deploying to production: ";

            read -p "should we use any specific git commit hash? empty to use latest: " build
            if [ -z $build ]
            then
                build="HEAD"
                echo "Using HEAD"
            fi

            echo "deploying to production: ";

            ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
export KUBECONFIG="/home/ubuntu/.kubeconfig" AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" 
cd application

if ./deploy.sh $build -production;
then
    kubectl get pods --namespace production -l role=opseng-challenge-app
    echo "On deployment completion Challenge App will we available on https://production.waveexample.site"
    echo "Checking for deployment completion..."
    until curl --output /dev/null --silent --head --fail https://production.waveexample.site/; do
        kubectl get pods --namespace production -l role=opseng-challenge-app
        echo "retrying required..."
        sleep 5
    done
    echo "Deployment completed, please visit https://production.waveexample.site/"
else
    echo "Deployment failed!"
fi

EOF

            break;;

        [Qq]* )
            exit;;

        * )
            echo "Please answer using 's', 'p'' or 'q': ";;

    esac
done
