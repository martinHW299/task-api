#!/usr/bin/env bash

# ============================================================
# Task API — ACR + Azure Container Apps setup (documented steps)
# ============================================================

# -----------------------------
# 0) Variables (edit as needed)
# -----------------------------
RG="task-api-rg"
LOCATION="eastus"
ACR_NAME="taskapiacr30901"
ENV_NAME="task-api-env"
APP_NAME="task-api"
IMAGE_NAME="task-api"
IMAGE_TAG="v2"

# App settings (DO NOT COMMIT real secrets)
APP_KEY="${APP_KEY:-base64:CHANGE_ME}"
DB_CONNECTION="${DB_CONNECTION:-sqlsrv}"
DB_HOST="${DB_HOST:-mhwserver.database.windows.net}"
DB_PORT="${DB_PORT:-1433}"
DB_DATABASE="${DB_DATABASE:-tasks}"
DB_USERNAME="${DB_USERNAME:-CloudSA7f1f4630}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME}"
DB_ENCRYPT="${DB_ENCRYPT:-true}"
DB_TRUST_SERVER_CERTIFICATE="${DB_TRUST_SERVER_CERTIFICATE:-true}"

echo "Using:"
echo "  RG=$RG"
echo "  LOCATION=$LOCATION"
echo "  ACR_NAME=$ACR_NAME"
echo "  ENV_NAME=$ENV_NAME"
echo "  APP_NAME=$APP_NAME"
echo "  IMAGE=$IMAGE_NAME:$IMAGE_TAG"
echo

# -----------------------------
# 1) Login + create RG + ACR
# -----------------------------
az login >/dev/null

az group create -n "$RG" -l "$LOCATION" >/dev/null
az acr create -n "$ACR_NAME" -g "$RG" --sku Basic >/dev/null

# Enable ACR admin user (you needed this for registry creds)
az acr update -n "$ACR_NAME" --admin-enabled true >/dev/null

# ACR server (loginServer)
ACR_SERVER="$(az acr show -n "$ACR_NAME" -g "$RG" --query loginServer -o tsv)"
echo "ACR_SERVER=$ACR_SERVER"

# Login docker to ACR
az acr login -n "$ACR_NAME" >/dev/null

# -----------------------------
# 2) Create Container Apps env
# -----------------------------
az containerapp env create -n "$ENV_NAME" -g "$RG" -l "$LOCATION" >/dev/null

# -----------------------------
# 3) Build image locally
# -----------------------------
docker build -t "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" .

# -----------------------------
# 4) (Optional) Run locally to test
# -----------------------------
echo
echo "Local test: http://localhost:8080/api/health  and  http://localhost:8080/api/tasks"
docker run --rm -p 8080:80 \
  -e APP_KEY="$APP_KEY" \
  -e DB_CONNECTION="$DB_CONNECTION" \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e DB_DATABASE="$DB_DATABASE" \
  -e DB_USERNAME="$DB_USERNAME" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_ENCRYPT="$DB_ENCRYPT" \
  -e DB_TRUST_SERVER_CERTIFICATE="$DB_TRUST_SERVER_CERTIFICATE" \
  "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# -----------------------------
# 5) Push image to ACR
# -----------------------------
docker push "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# Verify tag exists
az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output table

# -----------------------------
# 6) Deploy to Azure Container Apps
#    - Use secrets for DB_PASSWORD and APP_KEY
# -----------------------------
ACR_USER="$(az acr credential show -n "$ACR_NAME" --query "username" -o tsv)"
ACR_PASS="$(az acr credential show -n "$ACR_NAME" --query "passwords[0].value" -o tsv)"

az containerapp create \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --environment "$ENV_NAME" \
  --image "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" \
  --target-port 80 \
  --ingress external \
  --registry-server "$ACR_SERVER" \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --secrets \
    db-password="$DB_PASSWORD" \
    app-key="$APP_KEY" \
  --env-vars \
    APP_KEY=secretref:app-key \
    DB_CONNECTION="$DB_CONNECTION" \
    DB_HOST="$DB_HOST" \
    DB_PORT="$DB_PORT" \
    DB_DATABASE="$DB_DATABASE" \
    DB_USERNAME="$DB_USERNAME" \
    DB_PASSWORD=secretref:db-password \
    DB_ENCRYPT="$DB_ENCRYPT" \
    DB_TRUST_SERVER_CERTIFICATE="$DB_TRUST_SERVER_CERTIFICATE" \
  >/dev/null

FQDN="$(az containerapp show -n "$APP_NAME" -g "$RG" --query "properties.configuration.ingress.fqdn" -o tsv)"
echo
echo "Deployed! Base URL:"
echo "  https://$FQDN"
echo "Test:"
echo "  curl -i https://$FQDN/api/health"
echo "  curl -i https://$FQDN/api/tasks"

# -----------------------------
# 7) SQL Firewall note
# -----------------------------
cat <<EOF

NOTE: If you get 'Client with IP address ... is not allowed to access the server',
you must allow the Container App outbound IP(s) in Azure SQL firewall:

  az containerapp show -n "$APP_NAME" -g "$RG" --query properties.outboundIpAddresses -o tsv

Then add rules in Azure SQL Server -> Networking (Firewall rules), or via CLI.

EOF