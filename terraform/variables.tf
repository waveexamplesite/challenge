variable "aws_amis" {
    default = {
        us-east-1 = "ami-45b69e52"
        us-east-2 = "ami-1b772d7e"
    }
}

variable "bastion_instance_ip" {
    description = "AWS Bastion Host's IP"
}

variable "aws_region" {
    description = "AWS Region to Launch Servers"
    default = "us-east-2"
}

variable "elb_zones" {
  default = ["us-east-2a"]
}

variable "public_key_path" {
    description = "SSH Public Key Path"
}

variable "private_key_path" {
    description = "SSH Private Key Path"
}

variable "kubernetes_token" {
    description = "Kubernetes Cluster Join Token"
}

variable "master_userdata" {
    default = "kubernetes-master.sh"
}

variable "worker_userdata" {
    default = "kubernetes-node.sh"
}
