# HW6 Report

## What changed from HW5 and why?

HW5 orchestrates containers with Docker Swarm while HW6 orchestrates with lightweight Kubernetes (k3s) as Kubernetes is industry standard with better scalability and richer ecosystem.

## Detailed changes:
### Networking
HW5 uses overlay network and ingress routing mesh while k3s uses ClusterIP services for internal, NodePort for external, DNS-based service discovery. Hence, k3s networking is more flexible.

### Storage
HW5 bind mounts to host directory, while k3s uses PersistentVolume (PV) / PersistentVolumeClaim (PVC) with local path provisioner. Hence,kubernetes storage abstraction allows dynamic provisioning and portability.

### Deployment files
HW5 uses a single stack.yaml while k3s separate manifests per resource type (e.g. namespace.yaml, etc). Hence, kubernetes favours more granular and declarative resource definitions.

### Load balancing
HW5 uses built in ingress routing mesh across all nodes while HW6 uses service based load balancing and HorizontalPodAutoscaler for auto-scaling. Hence, kubernetes HPA enables auto-scaling based on metrics.

### Configuration Management
Swarm uses docker secrets and configs stored in Swarm's raft store, while k3s uses ConfigMaps for non-sensitive data and Secrets for credentials (base64 encoded). Hence, k3s separates configuration types better.

### Health Checks
Swarm's Healthcheck is in the service definition while k3s separates livenessProbe and readinessProbe. Hence, Kubernetes distinguishes between "is alive" vs "ready to serve traffic".

### Resource Management
Swarm's resource limits are in the service definitions while k3s separates requests (minimum) and limits (maximum) per container. Hence, k3s provides better resource scheduling.

## Conclusion:
Although there are added complexities in the setting up of kubernetes, kubernetes is the industry standard for orchestration and offers better scalability, ecosystem, cloud portability (as it is cloud native) and better resource management.
