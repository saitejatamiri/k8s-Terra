#!/bin/bash
set +xe

# Update system and install dependencies
sudo yum update -y
sudo yum install -y git conntrack

# Install Docker
sudo yum install -y docker
sudo amazon-linux-extras enable docker
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
sudo chown ec2-user:ec2-user /usr/local/bin/kubectl

# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/
sudo chown ec2-user:ec2-user /usr/local/bin/minikube

# Ensure PATH for ec2-user includes /usr/local/bin
if ! grep -q '/usr/local/bin' /home/ec2-user/.bash_profile; then
  echo 'export PATH=$PATH:/usr/local/bin' >> /home/ec2-user/.bash_profile
  sudo chown ec2-user:ec2-user /home/ec2-user/.bash_profile
fi

# Create systemd service file for minikube
sudo tee /etc/systemd/system/minikube.service > /dev/null <<EOF
[Unit]
Description=Minikube Kubernetes
After=docker.service
Requires=docker.service

[Service]
User=ec2-user
Group=ec2-user
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/minikube start --force
EOF

# Reload systemd, enable and start minikube service
sudo systemctl daemon-reload
sudo systemctl enable minikube
sudo systemctl start minikube

cat <<EOF > /home/ec2-user/delegate.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: harness-delegate-ng

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: harness-delegate-ng-cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: harness-delegate-ng
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

---

apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-delegate-tamiri-account-token
  namespace: harness-delegate-ng
type: Opaque
data:
  DELEGATE_TOKEN: "NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY="

---

# If delegate needs to use a proxy, please follow instructions available in the documentation
# https://ngdocs.harness.io/article/5ww21ewdt8-configure-delegate-proxy-settings

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    harness.io/name: kubernetes-delegate-tamiri
  name: kubernetes-delegate-tamiri
  namespace: harness-delegate-ng
spec:
  replicas: 1
  minReadySeconds: 120
  selector:
    matchLabels:
      harness.io/name: kubernetes-delegate-tamiri
  template:
    metadata:
      labels:
        harness.io/name: kubernetes-delegate-tamiri
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3460"
        prometheus.io/path: "/api/metrics"
    spec:
      terminationGracePeriodSeconds: 3600
      restartPolicy: Always
      containers:
      - image: us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.05.85903
        imagePullPolicy: Always
        name: delegate
        securityContext:
          allowPrivilegeEscalation: false
          runAsUser: 0
        ports:
          - containerPort: 8080
        resources:
          limits:
            memory: "2048Mi"
          requests:
            cpu: "0.5"
            memory: "2048Mi"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 3460
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /api/health
            port: 3460
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 15
        envFrom:
        - secretRef:
            name: kubernetes-delegate-tamiri-account-token
        env:
        - name: JAVA_OPTS
          value: "-Xms64M"
        - name: ACCOUNT_ID
          value: ucHySz2jQKKWQweZdXyCog
        - name: MANAGER_HOST_AND_PORT
          value: https://app.harness.io
        - name: DEPLOY_MODE
          value: KUBERNETES
        - name: DELEGATE_NAME
          value: kubernetes-delegate-tamiri
        - name: DELEGATE_TYPE
          value: "KUBERNETES"
        - name: DELEGATE_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: INIT_SCRIPT
          value: ""
        - name: DELEGATE_DESCRIPTION
          value: ""
        - name: DELEGATE_TAGS
          value: ""
        - name: NEXT_GEN
          value: "true"
        - name: CLIENT_TOOLS_DOWNLOAD_DISABLED
          value: "true"
        - name: DELEGATE_RESOURCE_THRESHOLD
          value: ""
        - name: DYNAMIC_REQUEST_HANDLING
          value: "false"

---

apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
   name: kubernetes-delegate-tamiri-hpa
   namespace: harness-delegate-ng
   labels:
       harness.io/name: kubernetes-delegate-tamiri
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kubernetes-delegate-tamiri
  minReplicas: 1
  maxReplicas: 1
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70

---

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: upgrader-cronjob
  namespace: harness-delegate-ng
rules:
  - apiGroups: ["batch", "apps", "extensions"]
    resources: ["cronjobs"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["extensions", "apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]

---

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-delegate-tamiri-upgrader-cronjob
  namespace: harness-delegate-ng
subjects:
  - kind: ServiceAccount
    name: upgrader-cronjob-sa
    namespace: harness-delegate-ng
roleRef:
  kind: Role
  name: upgrader-cronjob
  apiGroup: ""

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: upgrader-cronjob-sa
  namespace: harness-delegate-ng

---

apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-delegate-tamiri-upgrader-token
  namespace: harness-delegate-ng
type: Opaque
data:
  UPGRADER_TOKEN: "NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY="

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: kubernetes-delegate-tamiri-upgrader-config
  namespace: harness-delegate-ng
data:
  config.yaml: |
    mode: Delegate
    dryRun: false
    workloadName: kubernetes-delegate-tamiri
    namespace: harness-delegate-ng
    containerName: delegate
    delegateConfig:
      accountId: ucHySz2jQKKWQweZdXyCog
      managerHost: https://app.harness.io

---

apiVersion: batch/v1
kind: CronJob
metadata:
  labels:
    harness.io/name: kubernetes-delegate-tamiri-upgrader-job
  name: kubernetes-delegate-tamiri-upgrader-job
  namespace: harness-delegate-ng
spec:
  schedule: "0 */1 * * *"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 20
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: upgrader-cronjob-sa
          restartPolicy: Never
          containers:
          - image: harness/upgrader:latest
            name: upgrader
            imagePullPolicy: Always
            envFrom:
            - secretRef:
                name: kubernetes-delegate-tamiri-upgrader-token
            volumeMounts:
              - name: config-volume
                mountPath: /etc/config
          volumes:
            - name: config-volume
              configMap:
                name: kubernetes-delegate-tamiri-upgrader-config
EOF





