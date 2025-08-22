#!/bin/bash
set -euo pipefail

# Install kubectl if not available
install_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
  fi
}

# Install helm if not available  
install_helm() {
  if ! command -v helm &> /dev/null; then
    echo "Installing helm..."
    curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
    sudo mv linux-amd64/helm /usr/local/bin/
    rm -rf linux-amd64
  fi
}

# Create API secrets
create_api_secrets() {
  echo "Creating API secrets..."
  
  # Create HuggingFace secret
  kubectl create secret generic aktus-huggingface-secret \
    --from-literal=login-key="${PORTER_PARAM_HUGGINGFACE_API_KEY}" \
    --namespace "${PORTER_PARAM_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Create OpenAI secret
  kubectl create secret generic aktus-openai-secret \
    --from-literal=aktus-openai-key="${PORTER_PARAM_OPENAI_API_KEY}" \
    --namespace "${PORTER_PARAM_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
    
  echo "✅ API secrets created successfully"
}

# Create Azure storage secret
create_storage_secret() {
  echo "Creating Azure storage secret..."
  
  # Create Azure storage secret
  kubectl create secret generic azure-storage-secret \
    --from-literal=azurestorageaccountname="${PORTER_PARAM_STORAGE_ACCOUNT_NAME}" \
    --from-literal=azurestorageaccountkey="${PORTER_PARAM_STORAGE_ACCOUNT_KEY}" \
    --namespace "${PORTER_PARAM_NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
    
  echo "✅ Azure storage secret created successfully"
}

action=$1

case $action in
  install)
    echo "Installing Nexus Enterprise Platform..."
    echo "📦 Storage Account: ${PORTER_PARAM_STORAGE_ACCOUNT_NAME}"
    echo "📁 Containers: ${PORTER_PARAM_UPLOAD_CONTAINER_NAME}, ${PORTER_PARAM_PROCESSING_CONTAINER_NAME}, ${PORTER_PARAM_EXTRACTED_DATA_CONTAINER_NAME}, ${PORTER_PARAM_MODELS_CONTAINER_NAME}"
    
    # Install required tools
    install_kubectl
    install_helm
    
    # Create namespace
    kubectl create namespace "${PORTER_PARAM_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Add billing label to namespace for per-core pricing
    kubectl label namespace "${PORTER_PARAM_NAMESPACE}" azure-extensions-usage-release-identifier="${PORTER_PARAM_NAMESPACE}" --overwrite
    
    # Create service account
    kubectl create serviceaccount nexus-primary-cluster-sa \
      --namespace "${PORTER_PARAM_NAMESPACE}" \
      --dry-run=client -o yaml | kubectl apply -f -
    
    # Create API secrets
    create_api_secrets
    
    # Create storage secret
    create_storage_secret
    
    # Install Helm chart with enterprise configuration
    helm upgrade --install nexus-enterprise ../Nexus \
      --namespace "${PORTER_PARAM_NAMESPACE}" \
      --set "aktus-postgres-service.enabled=true" \
      --set "aktus-inference-service.enabled=${PORTER_PARAM_ENABLE_GPU_SERVICES}" \
      --set "aktus-database-service.dbConfig.password=${PORTER_PARAM_POSTGRES_PASSWORD}" \
      --set "global.azure.storage.account=${PORTER_PARAM_STORAGE_ACCOUNT_NAME}" \
      --set "global.azure.storage.key=${PORTER_PARAM_STORAGE_ACCOUNT_KEY}" \
      --set "global.azure.storage.containers.upload=${PORTER_PARAM_UPLOAD_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.processing=${PORTER_PARAM_PROCESSING_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.extracted=${PORTER_PARAM_EXTRACTED_DATA_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.models=${PORTER_PARAM_MODELS_CONTAINER_NAME}" \
      --set "global.azure.marketplace.planId=nexus-enterprise-plan" \
      --set "enterprise.security.enabled=${PORTER_PARAM_ENABLE_ENTERPRISE_SECURITY}" \
      --set "enterprise.sla.enabled=true" \
      --set "enterprise.support.level=premium" \
      --wait --timeout=15m
    
    # Set outputs
    mkdir -p /cnab/app/outputs
    echo "${PORTER_PARAM_NAMESPACE}" > /cnab/app/outputs/namespace
    echo "http://aktus-knowledge-assistant.${PORTER_PARAM_NAMESPACE}.svc.cluster.local:8080" > /cnab/app/outputs/application_url
    
    echo "Nexus Enterprise Platform installed successfully!"
    echo "Plan: Nexus Enterprise Plan"
    echo "Billing Model: Per-core ($10/hour per core)"
    echo "Features: Unlimited processing, enterprise security, 99.9% SLA"
    echo "🔐 API secrets configured securely"
    echo "📦 Blob storage configured: ${PORTER_PARAM_STORAGE_ACCOUNT_NAME}"
    echo "📁 Containers: Upload, Processing, Extracted Data, Models"
    ;;
    
  upgrade)
    echo "Upgrading Nexus Enterprise Platform..."
    
    # Install required tools
    install_kubectl
    install_helm
    
    # Update API secrets if they exist
    if kubectl get secret aktus-huggingface-secret -n "${PORTER_PARAM_NAMESPACE}" &>/dev/null; then
      create_api_secrets
    fi
    
    # Update storage secret
    create_storage_secret
    
    # Upgrade Helm chart
    helm upgrade nexus-enterprise ../Nexus \
      --namespace "${PORTER_PARAM_NAMESPACE}" \
      --set "aktus-postgres-service.enabled=true" \
      --set "aktus-inference-service.enabled=${PORTER_PARAM_ENABLE_GPU_SERVICES}" \
      --set "aktus-database-service.dbConfig.password=${PORTER_PARAM_POSTGRES_PASSWORD}" \
      --set "global.azure.storage.account=${PORTER_PARAM_STORAGE_ACCOUNT_NAME}" \
      --set "global.azure.storage.key=${PORTER_PARAM_STORAGE_ACCOUNT_KEY}" \
      --set "global.azure.storage.containers.upload=${PORTER_PARAM_UPLOAD_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.processing=${PORTER_PARAM_PROCESSING_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.extracted=${PORTER_PARAM_EXTRACTED_DATA_CONTAINER_NAME}" \
      --set "global.azure.storage.containers.models=${PORTER_PARAM_MODELS_CONTAINER_NAME}" \
      --set "global.azure.marketplace.planId=nexus-enterprise-plan" \
      --set "enterprise.security.enabled=${PORTER_PARAM_ENABLE_ENTERPRISE_SECURITY}" \
      --set "enterprise.sla.enabled=true" \
      --set "enterprise.support.level=premium" \
      --wait --timeout=15m
      
    echo "Nexus Enterprise Platform upgraded successfully!"
    ;;
    
  uninstall)
    echo "Uninstalling Nexus Enterprise Platform..."
    
    # Install required tools
    install_kubectl
    install_helm
    
    # Uninstall Helm chart
    helm uninstall nexus-enterprise --namespace "${PORTER_PARAM_NAMESPACE}" || true
    
    # Delete API secrets
    kubectl delete secret aktus-huggingface-secret -n "${PORTER_PARAM_NAMESPACE}" --ignore-not-found=true
    kubectl delete secret aktus-openai-secret -n "${PORTER_PARAM_NAMESPACE}" --ignore-not-found=true
    kubectl delete secret azure-storage-secret -n "${PORTER_PARAM_NAMESPACE}" --ignore-not-found=true
    
    # Delete service account
    kubectl delete serviceaccount nexus-primary-cluster-sa -n "${PORTER_PARAM_NAMESPACE}" --ignore-not-found=true
    
    # Delete namespace
    kubectl delete namespace "${PORTER_PARAM_NAMESPACE}" --ignore-not-found=true
    
    echo "Nexus Enterprise Platform uninstalled successfully!"
    echo "🔐 All secrets removed securely"
    ;;
    
  *)
    echo "Usage: $0 {install|upgrade|uninstall}"
    exit 1
    ;;
esac
