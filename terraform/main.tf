provider "aws" {
    region = "${var.aws_region}"
}

data "aws_caller_identity" "current" { }

resource "aws_key_pair" "ssh-key" {
    key_name = "joonathan-waveexample-kubernetes"
    public_key = "${file(var.public_key_path)}"
}

resource "aws_vpc" "kubernetes-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true

    tags {
        Name = "kubernetes-vpc"
        Environment = "joonathan-waveexample"
    }
}

/*
resource "aws_vpc_peering_connection" "kubernetes-vpc" {
    peer_owner_id = "${data.aws_caller_identity.current.account_id}"
    peer_vpc_id = "${var.bastion_vpc_id}"
    vpc_id = "${aws_vpc.kubernetes-vpc.id}"
    auto_accept = true

    tags {
      Name = "kubernetes-bastion-vpc-peering"
      Environment = "joonathan-waveexample"
    }
}
*/

resource "aws_subnet" "kubernetes-subnet" {
    vpc_id = "${aws_vpc.kubernetes-vpc.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true

    tags {
        Name = "kubernetes-subnet"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_internet_gateway" "kubernetes-gw" {
    vpc_id = "${aws_vpc.kubernetes-vpc.id}"

    tags {
        Name = "kubernetes-gateway"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_route" "kubernetes-internet-access" {
    route_table_id = "${aws_vpc.kubernetes-vpc.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kubernetes-gw.id}"
    depends_on = ["aws_internet_gateway.kubernetes-gw"]
}

resource "aws_security_group" "kubernetes-sg" {
    name = "kubernetes-sg"
    description = "Kubernetes Security Group"
    vpc_id = "${aws_vpc.kubernetes-vpc.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 6443
        to_port = 6443
        protocol = "tcp"
        cidr_blocks = ["${var.bastion_instance_ip}/32"]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["10.0.0.0/16"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "kubernetes-sg"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_security_group" "kubernetes-elb-sg" {
    name = "kubernetes-elb-sg"
    description = "Kubernetes ELB Security Group"
    vpc_id = "${aws_vpc.kubernetes-vpc.id}"

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "template_file" "master-userdata" {
    template = "${file("${var.master_userdata}")}"

    vars {
        kubernetes-token = "${var.kubernetes_token}"
    }
}

data "template_file" "worker-userdata" {
    template = "${file("${var.worker_userdata}")}"

    vars {
        kubernetes-token = "${var.kubernetes_token}"
        masterIP = "${aws_instance.kubernetes-master.private_ip}"
    }
}

resource "aws_instance" "kubernetes-master" {
    ami = "${lookup(var.aws_amis, var.aws_region)}"
    instance_type = "t2.medium"
    subnet_id = "${aws_subnet.kubernetes-subnet.id}"
    user_data = "${data.template_file.master-userdata.rendered}"
    key_name = "${aws_key_pair.ssh-key.key_name}"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.kubernetes-sg.id}"]

    provisioner "file" {
        connection {
            host = "${aws_instance.kubernetes-master.public_ip}"
            type = "ssh"
            user = "ubuntu"
            private_key = "${file(var.private_key_path)}"
        }
        source = "../kubernetes"
        destination = "/home/ubuntu"
    }

    tags {
        Name = "kubernetes-master"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_instance" "kubernetes-node1" {
    ami = "${lookup(var.aws_amis, var.aws_region)}"
    instance_type = "t2.medium"
    subnet_id = "${aws_subnet.kubernetes-subnet.id}"
    user_data = "${data.template_file.worker-userdata.rendered}"
    key_name = "${aws_key_pair.ssh-key.key_name}"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.kubernetes-sg.id}"]

    tags {
        Name = "kubernetes-node1"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_instance" "kubernetes-node2" {
    ami = "${lookup(var.aws_amis, var.aws_region)}"
    instance_type = "t2.medium"
    subnet_id = "${aws_subnet.kubernetes-subnet.id}"
    user_data = "${data.template_file.worker-userdata.rendered}"
    key_name = "${aws_key_pair.ssh-key.key_name}"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.kubernetes-sg.id}"]

    tags {
        Name = "kubernetes-node2"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_elb" "kubernetes-elb" {
    name = "kubernetes-elb"
    subnets = ["${aws_subnet.kubernetes-subnet.id}"]
    security_groups = ["${aws_security_group.kubernetes-elb-sg.id}"]

    listener {
        instance_port = 32080
        instance_protocol = "tcp"
        lb_port = 80
        lb_protocol = "tcp"
    }

    listener {
        instance_port = 32443
        instance_protocol = "tcp"
        lb_port = 443
        lb_protocol = "tcp"
    }

    instances = ["${aws_instance.kubernetes-node1.id}", "${aws_instance.kubernetes-node2.id}"]

    tags {
        Name = "kubernetes-elb"
        Environment = "joonathan-waveexample"
    }
}

resource "aws_proxy_protocol_policy" "web" {
    load_balancer = "${aws_elb.kubernetes-elb.name}"
    instance_ports = ["32080", "32443"]
}

resource "aws_route53_record" "kubernetes-catchall-dns" {
    zone_id = "ZACNZZ3RF9NO2"
    name = "*.waveexample.site"
    type = "CNAME"
    ttl = "300"
    records = ["${aws_elb.kubernetes-elb.dns_name}"]
}

resource "aws_route53_record" "kubernetes-apiserver-dns" {
    zone_id = "ZACNZZ3RF9NO2"
    name = "kubernetes-api.waveexample.site"
    type = "A"
    ttl = "300"
    records = ["${aws_instance.kubernetes-master.public_ip}"]
}

resource "null_resource" "kubernetes-master" {
    provisioner "remote-exec" {
        connection {
            host = "${aws_instance.kubernetes-master.public_ip}"
            type = "ssh"
            user = "ubuntu"
            private_key = "${file(var.private_key_path)}"
        }
        inline = [
            "while [ ! -f /etc/kubernetes/admin.conf ]; do sleep 2; done",
            "mkdir -p /home/ubuntu/.kube/",
            "sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config",
            "sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config",
        ]
    }
}

resource "null_resource" "kubernetes-config" {
    depends_on = ["null_resource.kubernetes-master"]
    provisioner "local-exec" {
        command = "scp -o 'StrictHostKeyChecking=no' ubuntu@${aws_instance.kubernetes-master.public_ip}:/home/ubuntu/.kube/config ~/.kubeconfig"
    }
}

resource "null_resource" "kubernetes-config-edit" {
    depends_on = ["null_resource.kubernetes-config"]
    provisioner "local-exec" {
        command = "sed -i.backup -r 's/(\\b[0-9]{1,3}\\.){3}[0-9]{1,3}\\b'/kubernetes-api.waveexample.site/ ~/.kubeconfig"
    }
}

resource "null_resource" "kubernetes-prepare-cluster" {
    depends_on = ["null_resource.kubernetes-config"]
    provisioner "remote-exec" {
        connection {
            host = "${aws_instance.kubernetes-master.public_ip}"
            type = "ssh"
            user = "ubuntu"
            private_key = "${file(var.private_key_path)}"
        }
        inline = [
            "while [ `kubectl get nodes --no-headers | wc -l` -lt 2 ]; do sleep 2; done",
            "sleep 10",
            "git clone https://github.com/kubernetes/contrib.git",
            "kubectl create -f contrib/ingress/controllers/nginx/examples/default-backend.yaml --namespace default",
            "kubectl expose rc default-http-backend --port=80 --target-port=8080 --name=default-http-backend --namespace default",
            "kubectl create -f contrib/ingress/controllers/nginx/examples/proxy-protocol/nginx-configmap.yaml --namespace default",
            "kubectl create -f contrib/ingress/controllers/nginx/examples/proxy-protocol/nginx-rc.yaml --namespace default",
            "kubectl create -f contrib/ingress/controllers/nginx/examples/proxy-protocol/nginx-svc.yaml --namespace default",
            "kubectl create -f kubernetes/lego.configmap.yaml --namespace default",
            "kubectl create -f kubernetes/lego.deployment.yaml --namespace default",
            "kubectl create -f kubernetes/production.namespace.yaml",
            "kubectl create -f kubernetes/staging.namespace.yaml",
        ]
    }
}
