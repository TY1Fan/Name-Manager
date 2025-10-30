# Docker Swarm Join Tokens

## Worker Join Token
Generated on: October 30, 2025

```bash
docker swarm join --token SWMTKN-1-3aqd8iwtuv58ymeh8n8onbfvkkqcjtpp1etuiw9zpfwsqeqvm2-5io45whb1mmdz3vwl1ekustlk 192.168.56.10:2377
```

## Manager Node
- **Node ID**: xqp4x8sow23gmb00upf0dru1y
- **Hostname**: swarm-manager
- **IP Address**: 192.168.56.10
- **Status**: Ready / Active
- **Manager Status**: Leader
- **Engine Version**: 28.5.1

## To Retrieve Tokens Later

If you need to retrieve the join token again:

```bash
# For worker token
vagrant ssh manager -c "docker swarm join-token worker"

# For manager token
vagrant ssh manager -c "docker swarm join-token manager"
```

## Usage

To join a worker node to this swarm:
1. SSH to the worker VM: `vagrant ssh worker`
2. Run the worker join command above
3. Verify with: `vagrant ssh manager -c "docker node ls"`
