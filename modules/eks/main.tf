
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

resource "aws_eks_node_group" "node_group" {
  cluster_name  = aws_eks_cluster.eks.name
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

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_role_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.node_group_role_AmazonEC2RoleforSSM,
    aws_iam_role_policy_attachment.node_group_role_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_role_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_role_CloudWatchAgentServerPolicy
  ]

  tags = merge({
    Name                 = aws_eks_cluster.eks.name
    "eks/cluster-name"   = aws_eks_cluster.eks.name
    "eks/nodegroup-name" = "${var.name}-nodegroup"
    "eks/nodegroup-type" = "managed"
  }, var.tags)
}
