# Feature Specification: Docker Swarm Multi-Node Orchestration

**Feature Branch**: `001-swarm-orchestration`  
**Created**: October 29, 2025  
**Status**: Draft  
**Input**: User description: "Refactor the current 3-tier webapp so that web and api run on my laptop (Swarm Manager) and database runs on my lab Linux node (Swarm worker). Orchestrate with Docker Swarm using a stack file; keep Compose for local dev."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Application to Distributed Infrastructure (Priority: P1)

As a developer, I need to deploy the Names Manager application across my laptop (manager node) and lab server (worker node) so that I can utilize my distributed infrastructure efficiently while maintaining service availability.

**Why this priority**: This is the core requirement - enabling the application to run in a multi-node cluster environment. Without this, the feature has no value.

**Independent Test**: Can be fully tested by deploying the stack to a two-node Swarm cluster and verifying all services start correctly on their designated nodes. Success is demonstrated when users can access the web interface through the manager node and data persists on the worker node.

**Acceptance Scenarios**:

1. **Given** a Swarm cluster with manager (laptop) and worker (lab server) nodes, **When** I deploy the stack file, **Then** the frontend and backend services start on the manager node and database service starts on the worker node
2. **Given** the application is deployed across nodes, **When** I add a name through the web interface, **Then** the data is stored in the database on the worker node and persists across service restarts
3. **Given** services are running on different physical machines, **When** I access the application from my laptop, **Then** all components communicate successfully across the network

---

### User Story 2 - Local Development with Compose (Priority: P2)

As a developer, I need to continue using Docker Compose for local development so that I can quickly iterate on code changes without requiring a multi-node cluster setup.

**Why this priority**: Maintains developer productivity by preserving the existing simple local development workflow while adding production-like orchestration capabilities.

**Independent Test**: Can be tested by running `docker-compose up` in the src directory and verifying all services start locally on a single machine. Demonstrates value by allowing rapid development without cluster configuration.

**Acceptance Scenarios**:

1. **Given** I have only Docker Compose installed, **When** I run the compose file in the src directory, **Then** all three services (frontend, backend, database) start successfully on my local machine
2. **Given** the application is running via Compose, **When** I make code changes and restart services, **Then** changes are reflected immediately without rebuilding the entire stack
3. **Given** I want to switch between local and distributed deployment, **When** I bring down the Compose deployment, **Then** I can deploy to Swarm without configuration conflicts

---

### User Story 3 - Service Health Monitoring Across Nodes (Priority: P3)

As an operator, I need to verify that all services across the cluster are healthy so that I can identify and respond to issues before they impact users.

**Why this priority**: Adds operational visibility but is not required for basic deployment functionality. Can be implemented after core orchestration is working.

**Independent Test**: Can be tested by checking service status in Swarm and verifying health check endpoints respond correctly. Delivers value by providing operational visibility without requiring the full application to be functional.

**Acceptance Scenarios**:

1. **Given** the stack is deployed to Swarm, **When** I query service status, **Then** I can see which services are running on which nodes and their health status
2. **Given** a service becomes unhealthy, **When** Swarm detects the failure, **Then** the service is automatically restarted according to restart policies
3. **Given** services are distributed across nodes, **When** I access health check endpoints, **Then** I receive appropriate responses indicating service readiness

---

### Edge Cases

- What happens when the worker node (database host) becomes unreachable?
  - Application should show graceful error messages
  - Swarm should attempt service recovery based on restart policy
  - Connection timeouts should be configured appropriately
  
- How does the system handle network latency between manager and worker nodes?
  - Database connection timeouts must accommodate network delays
  - Health checks should have appropriate intervals for distributed deployment
  
- What happens when deploying a stack update while services are running?
  - Swarm should perform rolling updates without complete service interruption
  - Database updates should preserve data integrity
  
- How do services behave if the Swarm manager node fails?
  - Services on worker nodes should continue running
  - Stack management becomes unavailable until manager is restored
  
- What happens when attempting to use the same port mappings in both Compose and Swarm?
  - Configuration should prevent port conflicts between deployment modes
  - Documentation should clearly specify which ports are used in each mode

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Docker Swarm stack file that deploys frontend and backend services to manager node and database service to worker node using placement constraints
- **FR-002**: System MUST maintain the existing Docker Compose file for local development with all three services deployable on a single machine
- **FR-003**: System MUST configure inter-service networking to allow frontend, backend, and database to communicate across physical nodes
- **FR-004**: Database service MUST persist data using volumes that survive service and node restarts
- **FR-005**: System MUST configure appropriate health checks for all services to enable Swarm to monitor and restart failed containers
- **FR-006**: Frontend service MUST be accessible from the manager node on a well-known port
- **FR-007**: System MUST use service discovery mechanisms to allow services to locate each other by name regardless of node placement
- **FR-008**: Stack deployment MUST respect dependency ordering (database starts before backend, backend starts before frontend)
- **FR-009**: System MUST document the process for initializing a Swarm cluster with manager and worker roles
- **FR-010**: System MUST configure restart policies to automatically recover from service failures

### Key Entities

- **Swarm Cluster**: The distributed Docker infrastructure consisting of one manager node (laptop) and one worker node (lab server). Responsible for service orchestration and scheduling.

- **Manager Node**: The laptop that runs Docker in Swarm manager mode. Hosts frontend and backend services, handles stack deployment commands, and orchestrates the cluster.

- **Worker Node**: The lab Linux server that runs Docker in Swarm worker mode. Hosts the database service and receives instructions from the manager.

- **Stack Definition**: The declarative YAML configuration specifying services, networks, volumes, and placement constraints for distributed deployment.

- **Compose Configuration**: The existing Docker Compose file for single-machine local development.

- **Overlay Network**: The software-defined network that enables service-to-service communication across physical nodes in the Swarm cluster.

- **Service Placement Constraints**: Configuration rules that control which nodes run which services (manager vs worker).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy the complete application to the distributed Swarm cluster with a single command and all services start within 60 seconds
- **SC-002**: Application maintains the same functionality when deployed via Swarm as it does when deployed via Compose (100% feature parity)
- **SC-003**: Developer can switch between local Compose deployment and distributed Swarm deployment in under 5 minutes
- **SC-004**: Data persists on the worker node database across service restarts, node restarts, and stack redeployments with 100% data retention
- **SC-005**: Services communicate successfully across nodes with network latency under 100ms for local network connections
- **SC-006**: Complete deployment documentation allows a new developer to set up both Compose and Swarm environments in under 30 minutes

## Assumptions

- The laptop (manager node) and worker node are on the same local network with reliable connectivity
- Worker node can be either a physical lab Linux server OR a Vagrant-managed Linux VM running on the laptop
- Both nodes have Docker installed with compatible versions that support Swarm mode
- The worker node is configured to accept Swarm worker registration from the manager
- Network firewall rules allow required Docker Swarm ports (2377, 7946, 4789) between nodes
- For Vagrant option: Host machine has sufficient resources (4GB+ RAM, 20GB+ disk) to run VM alongside manager services
- For Vagrant option: VM networking configured to allow bidirectional communication with host
- The developer has SSH or similar access to configure the worker node
- Existing application code does not need modification to support distributed deployment
- Database volume storage on the worker node has sufficient capacity and performance (10GB+ recommended)
- Local development will continue to use the default Docker Compose configuration without Swarm
- The single worker node architecture is sufficient (no high availability requirements)
- Both manager and worker nodes remain powered on and network-connected during normal operation

## Dependencies

- Docker Engine (version 20.10 or later) installed on both manager and worker nodes with Swarm mode capabilities
- Existing Docker Compose file and application code in the src directory
- Network connectivity between manager and worker nodes with necessary ports open
- Storage volume configuration on worker node for database persistence
- Existing environment variable configuration for application settings
- **Optional**: Vagrant (version 2.2 or later) and VirtualBox/VMware if using VM-based worker node
- **Optional**: Host machine with virtualization support enabled (VT-x/AMD-V) for Vagrant option
- **✅ READY**: Vagrant infrastructure files created (`vagrant/Vagrantfile`, `vagrant/VAGRANT_SETUP.md`, `vagrant/README.md`)

## Out of Scope

- Multi-manager high availability configuration (single manager is acceptable)
- Automatic service scaling based on load (static replica counts)
- Integration with external orchestration tools (Kubernetes, cloud platforms)
- Automated deployment CI/CD pipelines (manual deployment is acceptable)
- Service mesh or advanced networking features
- Monitoring and alerting infrastructure beyond basic health checks
- Load balancing across multiple replicas (single replica per service)
- Rolling updates with zero downtime (brief interruption acceptable)
- Secrets management beyond environment variables
- Backup and disaster recovery automation
