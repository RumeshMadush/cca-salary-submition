```bash
# 1. Build all images

docker build -t techsalary-local/identity:latest           services/identity/
docker build -t techsalary-local/salary-submission:latest  services/salary-submission/
docker build -t techsalary-local/stats:latest              services/stats/
docker build -t techsalary-local/vote:latest               services/vote/
docker build -t techsalary-local/search:latest             services/search/
docker build -t techsalary-local/bff:latest                services/bff/
docker build -t techsalary-local/frontend:latest           services/frontend/

# 2. Apply K8s manifests
kubectl apply -f k8s/namespace/namespace.yaml




docker pull postgres:15
kubectl delete pvc postgres-pvc -n data


kubectl apply -f k8s/local/postgres/

kubectl apply -f k8s/local/app/

# 3. Initialise database (first time only)
POD=$(kubectl get pod -n data -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -i -n data $POD -- psql -U salaryapp -d salarydb < db/init.sql

# 4. Apply ingress
            # Install ingress controller

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

            #  Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

            #   Re-apply your ingress (so controller picks it up)
kubectl apply -f k8s/ingress.yaml

# 5. Start port-forward (keep running in a separate terminal)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

Email: admin@example.com
Password: Admin123!