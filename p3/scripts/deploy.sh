#!/bin/bash

set -e


info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }

info "Creating namespaces 'argocd' and 'dev'..."
sudo kubectl create namespace argocd || true
sudo kubectl create namespace dev || true


info "Deploying ArgoCD..." # https://argo-cd.readthedocs.io/en/stable/getting_started/
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


info "Disabling ArgoCD server TLS, SSL is managed by Ingress..."
sudo kubectl -n argocd patch configmap argocd-cmd-params-cm \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

info "Setting up Ingress for ArgoCD..."
sudo kubectl apply -n argocd -f /vagrant/confs/ingress.yaml
sudo kubectl get svc argocd-server -n argocd -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'
sudo kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s


info "Adding argocd.pruiz-ca.com to /etc/hosts..."
echo "192.168.56.110 argocd.pruiz-ca.com" | sudo tee -a /etc/hosts


info "Waiting for Ingress route at https://argocd.pruiz-ca.com to be active (max 3 min)..."
SECONDS=0
until curl -k -s -o /dev/null -w "%{http_code}" https://argocd.pruiz-ca.com/ | grep -Eqv "404|000"; do
  if [[ $SECONDS -gt 180 ]]; then
    info "Error: Ingress route timed out."
    exit 1
  fi
  sleep 5
done


info "Configuring ArgoCD admin password..."
if [[ -f ./.pass ]]; then
  SAVED_PASSWORD=$(cat ./.pass)
  if ! sudo argocd login argocd.pruiz-ca.com --insecure --grpc-web --username admin --password "$SAVED_PASSWORD" --insecure; then
    rm ./.pass
  fi
fi

if [[ ! -f ./.pass ]]; then
  INITIAL_PASSWORD=$(sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  info "Initial password: [$INITIAL_PASSWORD]"
  sudo argocd login argocd.pruiz-ca.com --insecure --grpc-web --username admin --password "$INITIAL_PASSWORD" --insecure

  NEW_PASSWORD=$(openssl rand -base64 21 | tee ./.pass)
  sudo argocd account update-password --current-password "$INITIAL_PASSWORD" --new-password "$NEW_PASSWORD"
  info "New password: [$NEW_PASSWORD] (saved in ./.pass)"
fi


info "Deploying ft-token-manager application via ArgoCD..."
sudo kubectl apply -n argocd -f /vagrant/confs/app.yaml
sudo argocd app wait ft-token-manager --health --sync
sudo kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=ft-token-manager -n dev --timeout=180s


info "Port forwarding port 3000 to access the app..."
nohup sudo kubectl -n dev port-forward svc/ft-token-manager 3000:3000 > /dev/null 2>&1 &

info "When the repository is updated, you may need to set the port forwarding again"
info "Done! You can access ArgoCD at https://argocd.pruiz-ca.com (username: admin) and the app at http://localhost:3000/version"
