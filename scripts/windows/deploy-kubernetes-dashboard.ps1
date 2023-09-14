kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.0/aio/deploy/recommended.yaml
start "$(terraform output -raw eks_cluster_endpoint)/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
kubectl proxy --port=8080 --address=0.0.0.0 --disable-filter=true

# kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.0/aio/deploy/recommended.yaml

# https://archive.eksworkshop.com/beginner/040_dashboard/connect/
