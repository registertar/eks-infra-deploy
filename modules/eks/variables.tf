variable "name" {
  description = "The EKS name"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "The VPC id"
  type        = string
}

variable "public_subnet_ids" {
  description = "The public subnet ids"
  type        = list
}

variable "private_subnet_ids" {
  description = "The private subnet ids"
  type        = list
}

variable "desired_size" {
  description = "The desired size of node"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "The maximum size of node"
  type        = number
}

variable "min_size" {
  description = "The minimum size of node"
  type        = number
  default     = 0
}

variable "security_group_ids" {
  description = "The security groups to access EKS"
  type        = list
  default     = []
}

variable "tags" {
  description = "A map of tags to add to EKS"
  type        = map(string)
  default     = {}
}
