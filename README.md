# Kubectl commands

```
sudo kubectl get nodes -o wide # show controller name and INTERNAL-IP
sudo kubectl get deployments # show replicas
sudo kubectl get svc -A # show services (including traefik)


sudo kubectl get ingress --all-namespaces
sudo kubectl describe ingress
sudo kubectl get endpoints

sudo kubectl rollout restart deployment argocd-server -n argocd
```
