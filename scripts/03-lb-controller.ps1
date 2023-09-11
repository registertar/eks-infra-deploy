# ref: https://archive.eksworkshop.com/beginner/180_fargate/prerequisites-for-alb/
# ref: https://dev.to/aws-builders/deploying-simple-application-to-eks-on-fargate-5ee2

$LBC_VERSION = "v2.5.4"

$EKS_CLUSTER_NAME = $(terraform output -raw eks_cluster_name)
$ACCOUNT_ID = $(terraform output -raw account_id)
$AWS_REGION = $(terraform output -raw aws_region)
$VPC_ID = $(terraform output -raw vpc_id)

eksctl utils associate-iam-oidc-provider --cluster ${EKS_CLUSTER_NAME} --approve


Invoke-WebRequest -Uri https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json -OutFile iam_policy.json.tmp
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json.tmp
Remove-Item iam_policy.json.tmp


eksctl create iamserviceaccount `
  --cluster ${EKS_CLUSTER_NAME} `
  --namespace kube-system `
  --name aws-load-balancer-controller `
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy `
  --override-existing-serviceaccounts `
  --approve

kubectl get sa aws-load-balancer-controller -n kube-system -o yaml


kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"


helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm upgrade -i aws-load-balancer-controller `
    eks/aws-load-balancer-controller `
    -n kube-system `
    --set clusterName=${EKS_CLUSTER_NAME} `
    --set serviceAccount.create=false `
    --set serviceAccount.name=aws-load-balancer-controller `
    --set image.tag="${LBC_VERSION}" `
    --set region=${AWS_REGION} `
    --set vpcId=${VPC_ID}

kubectl -n kube-system rollout status deployment aws-load-balancer-controller

