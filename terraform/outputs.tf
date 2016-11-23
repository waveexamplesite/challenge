output "kubernetes-master-internal-ip" {
    value = "${aws_instance.kubernetes-master.private_ip}"
}

output "kubernetes-master-public-dns" {
    value = "${aws_instance.kubernetes-master.public_dns}"
}

output "kubernetes-master-public-ip" {
    value = "${aws_instance.kubernetes-master.public_ip}"
}

output "kubernetes-elb-public-dns" {
    value = "${aws_elb.kubernetes-elb.dns_name}"
}