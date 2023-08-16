terraform {
  backend "s3" {
    bucket = "eks-tfstates-development"
    key    = "eks-infra-deploy.tfstate"
    region = "eu-west-1"
  }
}
