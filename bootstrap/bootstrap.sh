#!/bin/bash

set -e

if [ -f "joonathan-waveexample-bastion.pem" ]; then
    echo "You might already have Bastion host bootstrapped"
    exit
fi

rm -f destroy.sh; touch destroy.sh
chmod +x destroy.sh

rm -f output_variables.sh; touch output_variables.sh

aws ec2 create-key-pair --key-name joonathan-waveexample-bastion --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["KeyMaterial"]' > joonathan-waveexample-bastion.pem
chmod 600 joonathan-waveexample-bastion.pem

BASTION_VPC_ID=`aws ec2 create-vpc --cidr-block 10.1.0.0/28 --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["Vpc"]["VpcId"]'`
echo "Bastion VPC created: $BASTION_VPC_ID"

BASTION_SUBNET_ID=`aws ec2 create-subnet --vpc-id $BASTION_VPC_ID --cidr-block 10.1.0.0/28 --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["Subnet"]["SubnetId"]'`
echo "Bastion Subnet created: $BASTION_SUBNET_ID"

BASTION_IG_ID=`aws ec2 create-internet-gateway --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["InternetGateway"]["InternetGatewayId"]'`
echo "Bastion InternetGatewat created: $BASTION_IG_ID"

aws ec2 attach-internet-gateway --vpc-id $BASTION_VPC_ID --internet-gateway-id $BASTION_IG_ID --region us-east-2 >/dev/null
echo "Bastion InternetGatewat attached to VPC"

BASTION_RTB_ID=`aws ec2 create-route-table --vpc-id $BASTION_VPC_ID --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["RouteTable"]["RouteTableId"]'`
echo "Bastion RouteTable created: $BASTION_RTB_ID"

aws ec2 create-route --route-table-id $BASTION_RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $BASTION_IG_ID --region us-east-2 >/dev/null
echo "Bastion Internet Traffic Route created"

aws ec2 associate-route-table --subnet-id $BASTION_SUBNET_ID --route-table-id $BASTION_RTB_ID --region us-east-2 >/dev/null

BASTION_SG_ID=`aws ec2 create-security-group --group-name kubernetes-bastion-sg --description "Security group for Bastion SSH access" --vpc-id $BASTION_VPC_ID --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["GroupId"]'`
echo "Bastion SecurityGroup created: $BASTION_SG_ID"

aws ec2 authorize-security-group-ingress --group-id $BASTION_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region us-east-2
echo "Bastion SecurityGroup ingress authorized for SSH on port 22"

BASTION_INSTANCE_ID=`aws ec2 run-instances --associate-public-ip-address --image-id ami-1b772d7e --count 1 --instance-type t2.micro --key-name joonathan-waveexample-bastion --security-group-ids $BASTION_SG_ID --subnet-id $BASTION_SUBNET_ID --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["Instances"][0]["InstanceId"]'`

echo "Bastion Instance launched: $BASTION_INSTANCE_ID waiting until up..."
aws ec2 wait instance-running --instance-ids $BASTION_INSTANCE_ID --region us-east-2

BASTION_INSTANCE_IP=`aws ec2 describe-instances --instance-ids $BASTION_INSTANCE_ID --region us-east-2 | python -c 'import sys, json; print json.load(sys.stdin)["Reservations"][0]["Instances"][0]["NetworkInterfaces"][0]["Association"]["PublicIp"]'`
echo "Instance $BASTION_INSTANCE_ID is up on IP $BASTION_INSTANCE_IP"
echo "Use the following command to acces the instance: ssh -i joonathan-waveexample-bastion.pem ubuntu@$BASTION_INSTANCE_IP"

echo "#!/bin/bash" >> output_variables.sh
echo "export BASTION_INSTANCE_IP=$BASTION_INSTANCE_IP" >> output_variables.sh
echo "export BASTION_VPC_ID=$BASTION_VPC_ID" >> output_variables.sh

sleep 10
until scp -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' -q -r application kubernetes terraform ubuntu@$BASTION_INSTANCE_IP:/home/ubuntu/; do
    sleep 15;
done

ssh -T -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP <<EOF
ssh-keygen -N "" -t rsa -b 4096 -C "ubuntu@$BASTION_INSTANCE_IP" -f ~/.ssh/id_rsa
sudo -i
apt-get update
apt-get install -y docker.io git unzip
usermod -aG docker ubuntu
wget https://releases.hashicorp.com/terraform/0.7.11/terraform_0.7.11_linux_amd64.zip
unzip terraform_0.7.11_linux_amd64.zip
chmod +x terraform
mv terraform /usr/local/bin/
wget https://storage.googleapis.com/kubernetes-release/release/v1.4.6/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/
EOF

echo "#!/bin/bash" >> destroy.sh
echo "( ./bootstrap/destroy_cluster.sh )" >> destroy.sh
echo "echo Cluster removed, removing Bastion host and resources" >> destroy.sh
echo "aws ec2 delete-key-pair --key-name joonathan-waveexample-bastion --region us-east-2" >> destroy.sh
echo "aws ec2 terminate-instances --instance-ids $BASTION_INSTANCE_ID --region us-east-2" >> destroy.sh
echo "aws ec2 wait instance-terminated --instance-ids $BASTION_INSTANCE_ID --region us-east-2"  >> destroy.sh
echo "aws ec2 delete-security-group --group-id $BASTION_SG_ID --region us-east-2" >> destroy.sh
echo "aws ec2 delete-subnet --subnet-id $BASTION_SUBNET_ID --region us-east-2" >> destroy.sh
echo "aws ec2 delete-route-table --route-table-id $BASTION_RTB_ID --region us-east-2" >> destroy.sh
echo "aws ec2 detach-internet-gateway --internet-gateway-id $BASTION_IG_ID --vpc-id $BASTION_VPC_ID --region us-east-2" >> destroy.sh
echo "aws ec2 delete-internet-gateway --internet-gateway-id $BASTION_IG_ID --region us-east-2" >> destroy.sh
echo "aws ec2 delete-vpc --vpc-id $BASTION_VPC_ID --region us-east-2" >> destroy.sh
echo "rm -f joonathan-waveexample-bastion.pem" >> destroy.sh
echo "rm -f output_variables.sh" >> destroy.sh
echo "rm -f destroy.sh" >> destroy.sh
echo "echo All done!" >> destroy.sh

echo "Run destroy.sh to remove Bastion instance and related resources"