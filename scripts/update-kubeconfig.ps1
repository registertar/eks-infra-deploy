aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name)
"`n# kubectl cluster-info"
kubectl cluster-info
"`n# kubectl get nodes"
kubectl get nodes
"`n# kubectl get all --all-namespaces"
kubectl get all --all-namespaces
