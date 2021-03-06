provider "aws" {
  region = "${var.region}"
}

module "label" {
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  attributes = "${var.attributes}"
  tags       = "${var.tags}"
  enabled    = "${var.enabled}"
}

module "cluster_label" {
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  delimiter  = "${var.delimiter}"
  attributes = ["${compact(concat(var.attributes, list("cluster")))}"]
  tags       = "${var.tags}"
  enabled    = "${var.enabled}"
}

locals {
    tags = "${merge(var.tags, map("kubernetes.io/cluster/${module.label.id}", "shared"))}"
}

module "vpc" {
  namespace  = "${var.namespace}"
  stage      = "${var.stage}"
  name       = "${var.name}"
  attributes = "${var.attributes}"
  tags       = "${local.tags}"
  cidr_block = "${var.vpc_cidr_block}"
}

module "subnets" {
  availability_zones  = ["${var.availability_zones}"]
  namespace           = "${var.namespace}"
  stage               = "${var.stage}"
  name                = "${var.name}"
  attributes          = "${var.attributes}"
  tags                = "${local.tags}"
  region              = "${var.region}"
  vpc_id              = "${module.vpc.vpc_id}"
  igw_id              = "${module.vpc.igw_id}"
  cidr_block          = "${module.vpc.vpc_cidr_block}"
  nat_gateway_enabled = "true"
}

module "eks_cluster" {
  source                  = "../../"
  namespace               = "${var.namespace}"
  stage                   = "${var.stage}"
  name                    = "${var.name}"
  attributes              = "${var.attributes}"
  tags                    = "${var.tags}"
  vpc_id                  = "${module.vpc.vpc_id}"
  subnet_ids              = ["${module.subnets.public_subnet_ids}"]
  allowed_security_groups = ["${var.allowed_security_groups_cluster}"]
  
  allowed_cidr_blocks = ["${var.allowed_cidr_blocks_cluster}"]
  enabled             = "${var.enabled}"
}

module "eks_workers" {
  namespace                          = "${var.namespace}"
  stage                              = "${var.stage}"
  name                               = "${var.name}"
  attributes                         = "${var.attributes}"
  tags                               = "${var.tags}"
  image_id                           = "${var.image_id}"
  eks_worker_ami_name_filter         = "${var.eks_worker_ami_name_filter}"
  instance_type                      = "${var.instance_type}"
  vpc_id                             = "${module.vpc.vpc_id}"
  subnet_ids                         = ["${module.subnets.public_subnet_ids}"]
  health_check_type                  = "${var.health_check_type}"
  min_size                           = "${var.min_size}"
  max_size                           = "${var.max_size}"
  wait_for_capacity_timeout          = "${var.wait_for_capacity_timeout}"
  associate_public_ip_address        = "${var.associate_public_ip_address}"
  cluster_name                       = "${module.cluster_label.id}"
  cluster_endpoint                   = "${module.eks_cluster.eks_cluster_endpoint}"
  cluster_certificate_authority_data = "${module.eks_cluster.eks_cluster_certificate_authority_data}"
  cluster_security_group_id          = "${module.eks_cluster.security_group_id}"
  allowed_security_groups            = ["${var.allowed_security_groups_workers}"]
  allowed_cidr_blocks                = ["${var.allowed_cidr_blocks_workers}"]
  enabled                            = "${var.enabled}"

  autoscaling_policies_enabled           = "${var.autoscaling_policies_enabled}"
  cpu_utilization_high_threshold_percent = "${var.cpu_utilization_high_threshold_percent}"
  cpu_utilization_low_threshold_percent  = "${var.cpu_utilization_low_threshold_percent}"
}
