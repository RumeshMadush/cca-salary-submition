# Kubernetes Storage: PVC & PV Learning Guide

A comprehensive guide to understanding PersistentVolumeClaims (PVC) and PersistentVolumes (PV) in Kubernetes, with practical examples from the CCA Salary Submission project.

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [PV vs PVC](#pv-vs-pvc)
3. [Storage Classes](#storage-classes)
4. [Dynamic vs Static Provisioning](#dynamic-vs-static-provisioning)
5. [Real-World Example: PostgreSQL](#real-world-example-postgresql)
6. [Lifecycle & Binding](#lifecycle--binding)
7. [Common Issues & Solutions](#common-issues--solutions)
8. [Best Practices](#best-practices)

---

## Core Concepts

### What is Storage in Kubernetes?

In Kubernetes, containers are **ephemeral** (temporary):
- Pod restarts → container data is lost
- Pod deletes → all data disappears

**Solution:** Persistent storage that survives pod restarts.

---

## PV vs PVC

### **PersistentVolume (PV)**

The **actual storage resource**:
- Physical hard drive space in your cluster
- Managed by cluster administrators
- Exists independent of pods
- Created and provisioned separately

**Analogy:** The actual apartment building

```yaml
# Example PV (created by admin)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-001
spec:
  capacity:
    storage: 10Gi                    # 10GB available
  accessModes:
    - ReadWriteOnce                  # Only one pod can write
  storageClassName: standard         # Storage type
  hostPath:
    path: /data/postgres             # Location on disk
```

---

### **PersistentVolumeClaim (PVC)**

A **request for storage** from your application:
- Pod or deployment requests storage
- Claims a specific amount from available PVs
- Acts as an interface between app and storage
- Application doesn't care WHERE the storage is

**Analogy:** Your rental application form requesting an apartment

```yaml
# Example PVC (created by app developer)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: data
spec:
  accessModes:
    - ReadWriteOnce                  # Need write access
  storageClassName: standard         # Match available storage
  resources:
    requests:
      storage: 5Gi                   # Need 5GB
```

---

## Relationship: How PV & PVC Connect

```
┌─────────────────────────────────────────────────┐
│          KUBERNETES CLUSTER                     │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  STORAGE (Admin manages)                 │  │
│  │                                          │  │
│  │  PersistentVolume (PV)                  │  │
│  │  ├─ Name: postgres-pv-001              │  │
│  │  ├─ Size: 10Gi                         │  │
│  │  ├─ Type: hostPath                     │  │
│  │  └─ Status: Available                  │  │
│  └──────────────────────────────────────────┘  │
│                     ↑                          │
│        (Claims storage from)                   │
│                     ↓                          │
│  ┌──────────────────────────────────────────┐  │
│  │  APPLICATION (App dev manages)           │  │
│  │                                          │  │
│  │  PersistentVolumeClaim (PVC)            │  │
│  │  ├─ Name: postgres-pvc                 │  │
│  │  ├─ Requests: 5Gi                     │  │
│  │  └─ Status: Bound to postgres-pv-001 │  │
│  └──────────────────────────────────────────┘  │
│                     ↑                          │
│        (Uses storage from)                     │
│                     ↓                          │
│  ┌──────────────────────────────────────────┐  │
│  │  POD (Container)                        │  │
│  │                                          │  │
│  │  Container: PostgreSQL                  │  │
│  │  Volume Mount: /var/lib/postgresql/data │  │
│  │  ├─ Mounted from: postgres-pvc         │  │
│  │  └─ Read/Write: Yes                    │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Storage Classes

A **StorageClass** defines **how** storage is provisioned.

Common storage classes in Docker Desktop Kubernetes:

```bash
$ kubectl get storageclass

NAME                 PROVISIONER             RECLAIMPOLICY
standard (default)   rancher.io/local-path   Delete
hostpath             rancher.io/local-path   Delete
```

### What StorageClass Does

| Field | Meaning |
|-------|---------|
| `provisioner` | What creates the actual storage (e.g., Docker, AWS, GCP) |
| `reclaimPolicy: Delete` | When PVC deleted → PV and data deleted automatically |
| `reclaimPolicy: Retain` | When PVC deleted → PV and data kept (manual cleanup) |
| `volumeBindingMode` | When to create storage (immediate or lazy) |

### StorageClass Example

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com          # AWS provisioner
parameters:
  type: gp3                            # SSD type
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete                 # Auto cleanup on delete
allowVolumeExpansion: true            # Can grow storage later
```

---

## Dynamic vs Static Provisioning

### **Static Provisioning (Old Way)**

Admin must **manually create PVs**:

```
1. Admin creates PV manually
   ↓
2. You create PVC requesting storage
   ↓
3. Kubernetes matches PVC to PV
   ↓
4. PVC Bound → Pod can use it
```

**Problem:** Admin creates PVs blindly, wastes resources

---

### **Dynamic Provisioning (Modern Way)**

Storage provisioner **automatically creates PVs**:

```
1. You create PVC requesting storage
   ↓
2. StorageClass provisioner sees the request
   ↓
3. Automatically creates a PV
   ↓
4. PVC Bound → Pod can use it
```

**Benefit:** On-demand storage, no admin overhead

---

## Real-World Example: PostgreSQL

This is exactly what we did in the CCA Salary Submission project.

### Step 1: Create PVC

**File:** `k8s/postgres/postgres-pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: data
spec:
  storageClassName: standard         # Use Docker Desktop's provisioner
  accessModes:
    - ReadWriteOnce                  # Only 1 pod can write at a time
  resources:
    requests:
      storage: 5Gi                   # Reserve 5GB
```

**What happens:**
1. You apply this PVC
2. Storage provisioner sees it
3. Automatically creates a PV with 5GB
4. PVC binds to that PV
5. Ready for use!

---

### Step 2: Use PVC in Deployment

**File:** `k8s/postgres/postgres-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: data
spec:
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data   # Inside container

      volumes:
      - name: pgdata
        persistentVolumeClaim:
          claimName: postgres-pvc                # Use the PVC we created
```

**What happens:**
1. Pod starts
2. Kubernetes finds PVC named `postgres-pvc`
3. Mounts the storage at `/var/lib/postgresql/data`
4. PostgreSQL reads/writes data there
5. If pod restarts → data still exists!

---

### Step 3: Verify It Works

```bash
# Check PVC status
kubectl get pvc -n data
# Expected: STATUS = Bound

# Check PV was auto-created
kubectl get pv
# Expected: Shows a PV bound to your PVC

# Check pod can use it
kubectl exec -n data <pod-name> -- ls -la /var/lib/postgresql/data
# Expected: Database files visible
```

---

## Lifecycle & Binding

### PVC Lifecycle States

```
1. PENDING
   └─ PVC created, looking for matching PV
   └─ Pod stays Pending until bound

2. BOUND
   └─ PVC found a PV and claimed it
   └─ Pod can now use the storage

3. RELEASED (old)
   └─ PVC deleted but PV exists
   └─ Depends on reclaimPolicy

4. FAILED
   └─ Something went wrong
   └─ Check kubectl describe
```

### Check State

```bash
# See ALL details
kubectl describe pvc -n data postgres-pvc

# Typical output when BOUND:
Name:          postgres-pvc
Namespace:     data
Status:        Bound
Volume:        pvc-8044e22a-217c-496d-b9d7-a66b6da2a52f
Capacity:      5Gi
Access Modes:  RWO (ReadWriteOnce)
```

---

## Common Issues & Solutions

### Issue 1: PVC Stuck in Pending

```bash
$ kubectl get pvc
NAME           STATUS    VOLUME   ACCESS MODES
postgres-pvc   Pending   <none>
```

**Causes:**
- StorageClass doesn't exist
- No PV available (static provisioning)
- Storage provisioner not running

**Fix:**

```bash
# Check available storage classes
kubectl get storageclass

# Specify a valid one in your PVC:
spec:
  storageClassName: standard    # ← Add this!
```

---

### Issue 2: Pod Can't Mount PVC

```
Error: pod has unbound immediate PersistentVolumeClaims
```

**Causes:**
- PVC not yet Bound
- PVC in different namespace

**Debug:**

```bash
# Check PVC status
kubectl describe pvc -n data postgres-pvc

# Check events for errors
kubectl describe pod -n data <pod-name>
# Look at Events section
```

---

### Issue 3: Storage-Provisioner CrashLoopBackOff

The provisioner itself is broken.

**Solution:**

```bash
# Option 1: Restart Docker Desktop
# (Cleanest, resets everything)

# Option 2: Check disk space
df -h
# If >90% full, free up space
```

---

## Best Practices

### 1. Use StorageClassName

Always specify `storageClassName`:

```yaml
# ❌ BAD - no storage class
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi

# ✅ GOOD - explicit storage class
spec:
  storageClassName: standard    # Clear intention
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

---

### 2. Match AccessModes

```yaml
accessModes:
  - ReadWriteOnce        # 1 pod can read+write (most common)
  - ReadOnlyMany         # Many pods read-only
  - ReadWriteMany        # Many pods read+write (NFS, etc)
```

For databases: use `ReadWriteOnce` (prevents corruption)

---

### 3. Size Your Storage

```yaml
# Too small → pod crashes when disk full
# Too large → wastes money

# For databases: estimate data growth
requests:
  storage: 5Gi    # Start conservative, can expand
```

---

### 4. Don't Use emptyDir for Permanent Data

```yaml
# ❌ WRONG for persistent data
volumes:
- name: data
  emptyDir: {}           # Lost on pod restart!

# ✅ RIGHT for persistent data
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc    # Survives restarts
```

---

### 5. Monitor PVC Usage

```bash
# Check how much space PVC is using
kubectl exec -n data <pod-name> -- df -h /var/lib/postgresql/data

# Expand PVC if needed (if allowVolumeExpansion: true)
kubectl patch pvc postgres-pvc -n data -p \
  '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

---

## Troubleshooting Checklist

```bash
# 1. Is StorageClass available?
kubectl get storageclass

# 2. Is PVC bound?
kubectl get pvc -n data
kubectl describe pvc -n data postgres-pvc

# 3. Did PV get created?
kubectl get pv

# 4. Can pod use it?
kubectl get pod -n data
kubectl describe pod -n data <pod-name>

# 5. Is storage-provisioner healthy?
kubectl get pods -n kube-system | grep storage-provisioner

# 6. Check events for errors
kubectl describe pvc -n data postgres-pvc
kubectl describe pod -n data <pod-name>
```

---

## Summary Table

| Aspect | PV | PVC |
|--------|----|----|
| **Created by** | Cluster admin | App developer |
| **Managed by** | Admin | Kubernetes |
| **Scope** | Cluster-wide | Namespace |
| **Purpose** | Provide storage | Request storage |
| **Binding** | One-time (static) or automatic (dynamic) | Requests PV |
| **Lifespan** | Independent of pods | Tied to app lifecycle |

---

## Key Takeaways

✅ **PV** = The actual storage (like a house)
✅ **PVC** = Request for storage (like a lease application)
✅ **StorageClass** = How storage is provisioned (rules for creating houses)
✅ **Dynamic Provisioning** = Automatic PV creation (modern way)
✅ **Use PVC in Deployments** = Apps stay storage-agnostic
✅ **Don't use emptyDir for permanent data** = It's temporary!

---

## Next Steps to Learn More

1. **Test it:** Create a test PVC and pod, write data, restart pod
2. **Expand PVC:** Practice changing storage size
3. **Multiple AccessModes:** Try ReadOnlyMany with multiple pods
4. **Different Storage Classes:** Explore hostpath vs standard
5. **Production:** Research cloud storage (AWS EBS, GCP Persistent Disk)

---

**Happy Learning!** 🚀
