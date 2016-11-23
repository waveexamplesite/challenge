#!/bin/bash

set -e

if [ ! -f "output_variables.sh" ]; then
    echo "You might not have cluster provisioned"
    exit
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo -n "We require AWS_ACCESS_KEY_ID: "; read AWS_ACCESS_KEY_ID
    export AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo -n "We require AWS_SECRET_ACCESS_KEY: "; read AWS_SECRET_ACCESS_KEY
   export AWS_SECRET_ACCESS_KEY
fi

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ]; then
   echo "AWS credentials not provided. Exiting"
   exit 2
fi

source output_variables.sh

ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" TF_VAR_kubernetes_token="$KUBERNETES_TOKEN" TF_VAR_bastion_instance_ip="$BASTION_INSTANCE_IP"
cd ~/terraform/
terraform destroy -force -var 'public_key_path=~/.ssh/id_rsa.pub' -var 'private_key_path=~/.ssh/id_rsa'
EOF