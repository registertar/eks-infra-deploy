locals {
  tags = {
    Repo = "eks-infra-deploy"
  }
  eks_name = "my-eks"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "master_cmk" {
  description             = "Master KMS key"
  deletion_window_in_days = 7
  tags                    = local.tags
}

resource "aws_kms_alias" "master_cmk" {
  name          = "alias/eks"
  target_key_id = aws_kms_key.master_cmk.key_id
}

module "networking" {
  source                     = "../../modules/networking"
  name                       = "my-vpc-for-eks"
  availability_zones         = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  vpc_cidr_block             = "10.0.0.0/16"
  public_subnets_cidr_block  = ["10.0.32.0/24", "10.0.96.0/24", "10.0.224.0/24"]
  private_subnets_cidr_block = ["10.0.0.0/19", "10.0.64.0/19", "10.0.128.0/19"]
  tags                       = local.tags
  eks_name                   = local.eks_name
}

module "eks" {
  source             = "../../modules/eks"
  name               = local.eks_name
  k8s_version        = "1.27"
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  min_size           = 2
  max_size           = 4
  desired_size       = 2
  tags               = local.tags
}
