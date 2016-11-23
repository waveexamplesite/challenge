# Wave Operations Engineering Development Challenge

> This is a [Kubernetes](http://kubernetes.io) based response to [Wave Operations Engineering Development Challenge](https://github.com/wvchallenges/opseng-challenge).
We will set up a 'bastion' host, brand new Kubernetes cluster, implement basic continuous integration practices and get the [example application](https://github.com/wvchallenges/opseng-challenge-app) deployed for both staging and production environments that we will be setting up.
To [run this example](#evaluation) there are no additional requirements from what has been described in the evaluation criteria of the challenge. The whole flow takes around 8 to 10 minutes to complete. 

[![asciicast](https://asciinema.org/a/6a8w6vw0p0d0i6z786g5zneqo.png)](https://asciinema.org/a/6a8w6vw0p0d0i6z786g5zneqo)

#### Introduction

After initial interview my plan was to show how [Kubernetes](http://kubernetes.io) could be leveraged as a solution to this challenged.
One of my principles was that ideally there should be no other requirements for the example to run locally (eg. not expect that Terraform, Ansible or other tools would be available) than what has been described in the evaluation criteria.

As [IAM Roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) are not available in the AWS account provided and the preferred ways of installing Kubernetes on AWS (for example [kops](https://github.com/kubernetes/kops) and [kube-aws by CoreOS](https://github.com/coreos/coreos-kubernetes)) rely heavily on IAM roles I decided to build a fully custom solution and naive (not production ready) brought up by some shell scripts and [Terraform](https://www.terraform.io).

Logging, monitoring and alerting were outside of the scope for this implementation. This is by no means a production grade solution.

#### Architecture overview

During the setup we use multitude of AWS resources from EC2 key-pair to VPC's and Route53 DNS records, but the main architecture is comprised of the following:

* Bastion Host
    - We use as this host a gateway for more complex operations. Has relevant Docker, Kubernetes (`kubectl`) and Terraform (`terraform`) tools installed.
    - This host is in it's own VPC and has access granted to Kubernetes API server via Security Group ingress rules
    - Docker images deployed on our Kubernetes cluster get built here [Docker images of the example application](https://hub.docker.com/r/joonathanwaveexample/opseng-challenge-app/tags/)
* Kubernetes cluster
    - Master + 2 nodes
    - [NGINX ingress controller](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx) with [kube-lego](https://github.com/jetstack/kube-lego) for automatic provisioning of SSL certificates 
    - Setup based on [kubeadm](http://kubernetes.io/docs/getting-started-guides/kubeadm/)
    - Namespaces for 'staging' and 'production'

We use Ubuntu 16.04 hvm-ssd EC2 images (ami-1b772d7e) for the basis of this setup.

*For the setup to work we had to prepare following things beforehand:*

* Registration of domain 'waveexample.site'
* AWS Route53 Zone setup as setting DNS servers after zone creation could delay evaluation of the solution due to DNS propagation times
* Setup of custom Docker repository [joonathanwaveexample/opseng-challenge-app](https://hub.docker.com/r/joonathanwaveexample/opseng-challenge-app/) as ECR can not be used without IAM
    - Pushing access is granted via symetrically encrypted Docker configuration file where `$AWS_SECRET_ACCESS_KEY` sent in with the task is used as the key.

*Project structure:*

* application/
    - example application related files including Dockerfile, Kubernetes deployment specifications and build scripts
* terraform/
    - Terraform configuration
    - Userdata for bringing up Kubernetes master and Node instances
* kubernetes/
    - Generic Kubernetes specifications for Namespaces and kube-lego
* bootstrap/
    - Scripts used to bring up and destroy the bastion and initiate cluster setup


#### Evaluation

To evaluate the solution please run the following

```
git clone https://github.com/waveexamplesite/challenge.git
cd challenge
./aws-app.sh
```

When the bastion host and Kubernetes cluster have not been set up yet the script will guide you through the bootstrapping process.
After the bootstrapping you will be asked whether you would like to build and deploy the example application to staging environment or to production.
Please be advised that deployment to production is not possible before the image has been built and used in staging environment.

To access the bastion host without using the `./aws-app.sh`. use the following:

```
source output_variables.sh
ssh -i joonathan-waveexample-bastion.pem -o 'StrictHostKeyChecking=no' ubuntu@$BASTION_INSTANCE_IP
```

To use `kubectl` in the bastion host please set the configuration location using `export KUBECONFIG="/home/ubuntu/.kubeconfig"`


#### Cleaning up

After evaluating the solution `./destroy.sh` can be called to clean up resources created by Terraform and the `./aws-app.sh` script.
