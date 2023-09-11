output "MASTER_ARN" {
  value = aws_kms_alias.master_cmk.arn
}

output "eks_cluster_endpoint" {
  value = module.EKS.eks_cluster_endpoint
}

output "eks_cluster_name" {
  value = module.EKS.eks_cluster_name
}

output "kubeconfig_certificate_authority_data" {
  value = module.EKS.kubeconfig_certificate_authority_data
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "vpc_id" {
  value = module.Networking.vpc_id
}