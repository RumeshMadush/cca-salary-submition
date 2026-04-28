#!/bin/bash
# =============================================================================
# EC2 User Data Script - MicroK8s Cluster Bootstrap
# OS: Ubuntu 22.04 / 24.04 LTS
# Repo: https://github.com/RumeshMadush/cca-salary-submition
# Branch: ci_cd_pipeline_setup
# =============================================================================

#set -euo pipefail
#exec > >(tee /var/log/userdata.log | logger -t userdata -s 2>/dev/console) 2>&1

echo "============================================"
echo " EC2 MicroK8s Bootstrap Starting"
echo " Timestamp: $(date)"
echo " OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
echo "============================================"

# -----------------------------------------------
# 1. SYSTEM UPDATE & PREREQUISITES
# -----------------------------------------------
echo "[1/8] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    gnupg \
    jq \
    net-tools \
    snapd

# -----------------------------------------------
# 2. INSTALL DOCKER
# -----------------------------------------------
echo "[2/8] Installing Docker..."

apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu
echo "Docker version: $(docker --version)"

# -----------------------------------------------
# 3. INSTALL MICROK8S
# -----------------------------------------------
echo "[3/8] Installing MicroK8s..."

# Ensure snapd is running (Ubuntu has it built in)
systemctl enable snapd
systemctl start snapd

# Classic snap support symlink
ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true

# Wait for snapd to be ready
echo "Waiting for snapd..."
for i in {1..12}; do
    if snap version &>/dev/null; then
        echo "  snapd ready."
        break
    fi
    echo "  Attempt $i/12: waiting 5s..."
    sleep 5
done

# Install MicroK8s
snap install microk8s --classic --channel=1.31/stable

# Add ubuntu user to microk8s group
usermod -aG microk8s ubuntu

# Set up .kube dir for ubuntu user
mkdir -p /home/ubuntu/.kube
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Wait for MicroK8s to be ready
echo "Waiting for MicroK8s to be ready (up to 5 minutes)..."
microk8s status --wait-ready --timeout=300 || {
    echo "ERROR: MicroK8s failed to start in time"
    microk8s status
    exit 1
}
echo "MicroK8s is ready."

# -----------------------------------------------
# 4. ENABLE MICROK8S ADDONS
# -----------------------------------------------
echo "[4/8] Enabling MicroK8s addons..."

microk8s enable dns
microk8s enable storage
microk8s enable ingress
microk8s enable helm3
microk8s enable metrics-server

echo "Waiting 30s for addons to settle..."
sleep 30
microk8s status

# -----------------------------------------------
# 5. CONFIGURE KUBECTL
# -----------------------------------------------
echo "[5/8] Configuring kubectl..."

# System-wide kubectl wrapper
cat > /usr/local/bin/kubectl <<'EOF'
#!/bin/bash
exec /snap/bin/microk8s kubectl "$@"
EOF
chmod +x /usr/local/bin/kubectl

# Kubeconfig for root (used during this script execution)
mkdir -p /root/.kube
microk8s config > /root/.kube/config
chmod 600 /root/.kube/config
export KUBECONFIG=/root/.kube/config

# Kubeconfig for ubuntu user
microk8s config > /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Shell config for ubuntu user
cat >> /home/ubuntu/.bashrc <<'BASHRC'

# MicroK8s / Kubernetes
alias kubectl='microk8s kubectl'
alias k='microk8s kubectl'
export KUBECONFIG=$HOME/.kube/config
BASHRC

# Shell config for root
cat >> /root/.bashrc <<'BASHRC'

# MicroK8s / Kubernetes
alias kubectl='microk8s kubectl'
alias k='microk8s kubectl'
export KUBECONFIG=/root/.kube/config
BASHRC

echo "kubectl version: $(kubectl version --client)"

# -----------------------------------------------
# 6. CLONE REPOSITORY & SWITCH BRANCH
# -----------------------------------------------
echo "[6/8] Cloning repository..."

REPO_URL="https://github.com/RumeshMadush/cca-salary-submition"
BRANCH="ci_cd_pipeline_setup"
APP_DIR="/opt/app/cca-salary-submition"

mkdir -p /opt/app
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"
git checkout "$BRANCH"
echo "Cloned to $APP_DIR, branch: $(git branch --show-current)"

# -----------------------------------------------
# 7. DEPLOY KUBERNETES MANIFESTS
# -----------------------------------------------
echo "[7/8] Deploying Kubernetes manifests..."
cd "$APP_DIR"

kubectl get nodes

echo "Creating namespace..."
kubectl apply -f k8s/namespace/namespace.yaml

echo "Deploying PostgreSQL..."
kubectl apply -f k8s/postgres/postgres-secret.yaml
kubectl apply -f k8s/postgres/postgres-pvc.yaml
kubectl apply -f k8s/postgres/postgres-deployment.yaml

echo "Waiting for PostgreSQL pod to be ready (timeout: 5 min)..."
if ! kubectl wait --for=condition=ready pod -l app=postgres -n data --timeout=300s; then
    echo "ERROR: PostgreSQL pod did not become ready in time."
    kubectl get pods -n data -l app=postgres -o wide
    kubectl describe pod -l app=postgres -n data
    kubectl logs -l app=postgres -n data --tail=50 2>/dev/null || true
    exit 1
fi
echo "PostgreSQL is ready."

echo "Init PostgreSQL DB..."
bash ./scripts/m1/init-db.sh

echo "Applying app config and secrets..."
kubectl apply -f k8s/configmap/configmap.yaml
kubectl apply -f k8s/secret/app-secret.yaml

echo "Applying services..."
kubectl apply -f k8s/services/

echo "Deploying app..."
kubectl apply -f k8s/app/

echo "Applying ingress..."
kubectl apply -f k8s/ingress.yaml

# -----------------------------------------------
# 8. GITHUB ACTIONS SERVICE ACCOUNT & TOKEN
# -----------------------------------------------
echo "[8/8] Setting up GitHub Actions ServiceAccount and token..."

kubectl apply -f k8s/github-actions-sa.yaml
kubectl apply -f k8s/github-actions-token.yaml

echo "Waiting for token to be populated..."
TOKEN=""
for i in {1..20}; do
    TOKEN=$(kubectl get secret github-actions-token -n app \
        -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
    if [ -n "$TOKEN" ]; then
        echo "  Token ready."
        break
    fi
    echo "  Attempt $i/20: not ready, retrying in 5s..."
    sleep 5
done

if [ -z "$TOKEN" ]; then
    echo "ERROR: Token was not populated. Check: kubectl describe secret github-actions-token -n app"
    exit 1
fi

# FIX: Use the correct AWS IMDSv2 metadata endpoint — NOT a hardcoded IP
# Step 1: get a session token (IMDSv2 requirement)
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || echo "")

# Step 2: use the token to get the public IP
if [ -n "$IMDS_TOKEN" ]; then
    EC2_PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
        http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unavailable")
else
    # Fallback to IMDSv1
    EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "unavailable")
fi

API_SERVER_EXTERNAL="https://${EC2_PUBLIC_IP}:16443"
CA_CERT=$(kubectl get secret github-actions-token -n app -o jsonpath='{.data.ca\.crt}')

# -----------------------------------------------
# DEPLOYMENT SUMMARY
# -----------------------------------------------
echo ""
echo "============================================"
echo " Deployment Summary — $(date)"
echo "============================================"
echo "--- Pods: data namespace ---"
kubectl get pods -n data
echo "--- Pods: app namespace ---"
kubectl get pods -n app
echo "--- Services: app namespace ---"
kubectl get svc -n app
echo "--- Ingress: app namespace ---"
kubectl get ingress -n app
echo "--- Nodes ---"
kubectl get nodes -o wide

# -----------------------------------------------
# GITHUB SECRETS OUTPUT
# -----------------------------------------------
echo ""
echo "============================================"
echo " GitHub Actions Secrets"
echo " Add to: Repo → Settings → Secrets → Actions"
echo "============================================"
echo "KUBE_API_SERVER : ${API_SERVER_EXTERNAL}"
echo "KUBE_TOKEN      : ${TOKEN}"
echo "KUBE_CA_CERT    : ${CA_CERT}"

cat > /root/github-actions-secrets.txt <<SECRETS
# Generated: $(date)
# GitHub repo → Settings → Secrets and variables → Actions

KUBE_API_SERVER
${API_SERVER_EXTERNAL}

KUBE_TOKEN
${TOKEN}

KUBE_CA_CERT (base64-encoded)
${CA_CERT}
SECRETS
chmod 600 /root/github-actions-secrets.txt

echo ""
echo "============================================"
echo " Bootstrap Complete!"
echo " App dir        : $APP_DIR"
echo " Full logs      : /var/log/userdata.log"
echo " GitHub secrets : /root/github-actions-secrets.txt"
echo " API server     : ${API_SERVER_EXTERNAL}"
echo "============================================"