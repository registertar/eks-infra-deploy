
# Define the role to be attached EKS
resource "aws_iam_role" "eks_role" {
  name               = "${var.name}-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sts:AssumeRole"
        ],
        "Principal" : {
          "Service" : [
            "eks.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge({}, var.tags)
}

# Attach the CloudWatchFullAccess policy to EKS role
resource "aws_iam_role_policy_attachment" "eks_role_CloudWatchFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.eks_role.name
}

resource "aws_iam_role_policy_attachment" "eks_role_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# Optionally, enable Security Groups for Pods
resource "aws_iam_role_policy_attachment" "eks_role_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_role.name
}

# Default Security Group of EKS
resource "aws_security_group" "eks_security_group" {
  name        = "${var.name} Security Group"
  description = "Default SG to allow traffic from the EKS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = "0"
    to_port         = "0"
    protocol        = "TCP"
    security_groups = var.security_group_ids
  }

  tags = merge({}, var.tags)
}

resource "aws_cloudwatch_log_group" "eks_logs" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 7

  tags = merge({}, var.tags)
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  name    = var.name
  version = var.k8s_version

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [
      "0.0.0.0/0",
    ]
    security_group_ids = [
      aws_security_group.eks_security_group.id
    ]
    subnet_ids = flatten([var.public_subnet_ids, var.private_subnet_ids])
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_role_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_role_AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.eks_role_CloudWatchFullAccess,
    aws_cloudwatch_log_group.eks_logs
  ]

  tags = merge({}, var.tags)

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, because eksctl updates those
      tags, tags_all
    ]
  }
}

resource "aws_iam_role" "node_group_role" {
  name                  = "${var.name}-node-group-role"
  path                  = "/"
  force_detach_policies = false
  max_session_duration  = 3600
  assume_role_policy    = jsonencode(
    {
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )

  tags = merge({}, var.tags)
}

resource "aws_iam_role_policy_attachment" "node_group_role_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group_role_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group_role_AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group_role_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group_role_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role" "eks_fargate_profile_role" {
  name = "eks-fargate-profile-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = merge({}, var.tags)
}

resource "aws_iam_role_policy_attachment" "eks_fargate_profile_role_AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_profile_role.name
}

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "${var.name}-kube-system"
  pod_execution_role_arn = aws_iam_role.eks_fargate_profile_role.arn

  # These subnets must have the following resource tag: 
  # kubernetes.io/cluster/<CLUSTER_NAME>.
  subnet_ids = flatten([var.private_subnet_ids])

  selector {
    namespace = "kube-system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_profile_role_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge({
    "eks/cluster-name"   = aws_eks_cluster.eks.name
  }, var.tags)
}

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.eks.name
  fargate_profile_name   = "${var.name}-default"
  pod_execution_role_arn = aws_iam_role.eks_fargate_profile_role.arn

  # These subnets must have the following resource tag: 
  # kubernetes.io/cluster/<CLUSTER_NAME>.
  subnet_ids = flatten([var.private_subnet_ids])

  selector {
    namespace = "default"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_fargate_profile_role_AmazonEKSFargatePodExecutionRolePolicy
  ]

  tags = merge({
    "eks/cluster-name"   = aws_eks_cluster.eks.name
  }, var.tags)
}

/*
resource "aws_eks_node_group" "node_group" {
  cluster_name  = aws_eks_cluster.eks.name
  instance_types = ["t3.small"]
  disk_size     = 20
  capacity_type = "SPOT"
  labels        = {
    "eks/cluster-name"   = aws_eks_cluster.eks.name
    "eks/nodegroup-name" = "${var.name}-nodegroup"
  }
  node_group_name = "${var.name}-nodegroup"
  node_role_arn   = aws_iam_role.node_group_role.arn

  subnet_ids = flatten([var.private_subnet_ids])

  scaling_config {
    min_size     = var.min_size
    max_size     = var.max_size
    desired_size = var.desired_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_role_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_group_role_AmazonEC2RoleforSSM,
    aws_iam_role_policy_attachment.node_group_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_role_CloudWatchAgentServerPolicy
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = merge({
    Name                 = aws_eks_cluster.eks.name
    "eks/cluster-name"   = aws_eks_cluster.eks.name
    "eks/nodegroup-name" = "${var.name}-nodegroup"
    "eks/nodegroup-type" = "managed"
  }, var.tags)
}
*/

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  is_linux = length(regexall("/home/", lower(abspath(path.root)))) > 0
}

resource "terraform_data" "eks_provisioner_linux" {
  count = local.is_linux ? 1 : 0

  # https://github.com/hashicorp/terraform/issues/23679
  # Destroy-time provisioners and their connection configurations may only reference attributes of the related resource, via 'self', 'count.index', or 'each.key'.
  triggers_replace = {
    EKS_CLUSTER_NAME = aws_eks_cluster.eks.name
    ACCOUNT_ID = data.aws_caller_identity.current.account_id
    AWS_REGION = data.aws_region.current.name
    VPC_ID = var.vpc_id
  }

  provisioner "local-exec" {
    command = "scripts/linux/01-update-kubeconfig.sh"
    working_dir = path.module
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
    }
  }

  provisioner "local-exec" {
    command = "scripts/linux/02-patch-coredns-deployment.sh"
    working_dir = path.module
  }

  provisioner "local-exec" {
    command = "scripts/linux/03-lb-controller.sh"
    working_dir = path.module
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
      ACCOUNT_ID = self.triggers_replace.ACCOUNT_ID
      AWS_REGION = self.triggers_replace.AWS_REGION
      VPC_ID = self.triggers_replace.VPC_ID
    }
  }

  # destroy

  provisioner "local-exec" {
    when = destroy
    command = "scripts/linux/03-lb-controller-destroy.sh"
    working_dir = path.module
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
    }
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_fargate_profile.kube_system,
    aws_eks_fargate_profile.default
  ]
}

resource "terraform_data" "eks_provisioner_windows" {
  count = local.is_linux ? 0 : 1

  # https://github.com/hashicorp/terraform/issues/23679
  # Destroy-time provisioners and their connection configurations may only reference attributes of the related resource, via 'self', 'count.index', or 'each.key'.
  triggers_replace = {
    EKS_CLUSTER_NAME = aws_eks_cluster.eks.name
    ACCOUNT_ID = data.aws_caller_identity.current.account_id
    AWS_REGION = data.aws_region.current.name
    VPC_ID = var.vpc_id
  }

  provisioner "local-exec" {
    command = "scripts\\windows\\01-update-kubeconfig.ps1"
    working_dir = path.module
    interpreter = ["PowerShell", "-Command"]
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
    }
  }

  provisioner "local-exec" {
    command = "scripts\\windows\\02-patch-coredns-deployment.ps1"
    working_dir = path.module
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    command = "scripts\\windows\\03-lb-controller.ps1"
    working_dir = path.module
    interpreter = ["PowerShell", "-Command"]
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
      ACCOUNT_ID = self.triggers_replace.ACCOUNT_ID
      AWS_REGION = self.triggers_replace.AWS_REGION
      VPC_ID = self.triggers_replace.VPC_ID
    }
  }

  # destroy

  provisioner "local-exec" {
    when = destroy
    command = "scripts\\windows\\93-lb-controller-destroy.ps1"
    working_dir = path.module
    interpreter = ["PowerShell", "-Command"]
    environment = {
      EKS_CLUSTER_NAME = self.triggers_replace.EKS_CLUSTER_NAME
    }
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_eks_fargate_profile.kube_system,
    aws_eks_fargate_profile.default
  ]
}
