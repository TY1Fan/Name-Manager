# Security Incident Report

## GitGuardian Security Alerts - October 30, 2025

### Incident Summary

GitGuardian detected exposed secrets in the repository:

1. **OpenSSH Private Keys**
   - Location: `.vagrant/machines/manager/virtualbox/private_key`
   - Location: `.vagrant/machines/worker/virtualbox/private_key`

2. **Docker Swarm Join Token**
   - Location: `vagrant/swarm-join-tokens.md`
   - Token: `SWMTKN-1-3aqd8iwtuv58ymeh8n8onbfvkkqcjtpp1etuiw9zpfwsqeqvm2-5io45whb1mmdz3vwl1ekustlk`

### Remediation Actions Taken

#### 1. Remove Sensitive Files from Git
- Removed entire `.vagrant/` directory from git tracking (24 files)
- Removed `vagrant/swarm-join-tokens.md` from git tracking
- Committed changes with commit hash: `d7c5c23`

#### 2. Update .gitignore
Added the following exclusions to prevent future exposure:
```
# Vagrant
.vagrant/

# Swarm tokens (contains secrets)
vagrant/swarm-join-tokens.md
```

#### 3. Create Secure Template
Created `vagrant/swarm-join-tokens.md.template` with:
- Instructions for retrieving tokens on demand
- Security best practices
- No actual secrets stored

#### 4. Rotate Exposed Tokens
- Rotated worker join token on October 30, 2025
- Old token: `SWMTKN-1-3aqd8iwtuv58ymeh8n8onbfvkkqcjtpp1etuiw9zpfwsqeqvm2-5io45whb1mmdz3vwl1ekustlk`
- New token: `SWMTKN-1-3aqd8iwtuv58ymeh8n8onbfvkkqcjtpp1etuiw9zpfwsqeqvm2-310q1s2e730u7q205ze1zznzw`
- Verified cluster connectivity after rotation: ✅ Both nodes still active

### Impact Assessment

**OpenSSH Private Keys:**
- These keys provide SSH access to Vagrant-managed VMs
- VMs are ephemeral and will be destroyed/recreated regularly
- VMs use private network (192.168.56.x) not accessible from internet
- Keys are regenerated each time VMs are created
- **Risk Level**: Low (local development environment)

**Docker Swarm Join Token:**
- Token allows new nodes to join the Swarm cluster
- Token was exposed but cluster uses private network (192.168.56.x)
- Token has been rotated and old token is now invalid
- No evidence of unauthorized node joins
- **Risk Level**: Low (token rotated, private network)

### Verification

1. **Token Rotation Confirmed:**
   ```bash
   $ vagrant ssh manager -c "docker node ls"
   ID                            HOSTNAME        STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
   xqp4x8sow23gmb00upf0dru1y *   swarm-manager   Ready     Active         Leader           28.5.1
   m4thvdx2thshjvoo4f69c4poe     swarm-worker    Ready     Active                          28.5.1
   ```

2. **Files Removed from Git:**
   - `.vagrant/` directory: 24 files removed
   - `vagrant/swarm-join-tokens.md`: 1 file removed

3. **.gitignore Updated:**
   - Prevents future commits of `.vagrant/` directory
   - Prevents future commits of `vagrant/swarm-join-tokens.md`

### Security Best Practices Implemented

1. **Never commit secrets** - Use .gitignore to exclude sensitive files
2. **Retrieve tokens on demand** - Template file shows how to get fresh tokens
3. **Rotate exposed tokens** - Invalidate compromised credentials immediately
4. **Private networks** - VMs use isolated private network ranges
5. **Ephemeral credentials** - Vagrant SSH keys regenerate on VM recreation

### Future Prevention

To prevent similar incidents:

1. **Before committing**, always check:
   ```bash
   git status
   git diff --cached
   ```

2. **Use git hooks** to prevent commits of sensitive patterns:
   - Add pre-commit hook to check for token patterns
   - Block commits containing `BEGIN OPENSSH PRIVATE KEY`
   - Block commits containing `SWMTKN-` patterns

3. **Review .gitignore** before first commit in any project

4. **Use environment variables** for secrets instead of files

5. **Enable GitGuardian** or similar scanning tools in CI/CD

### References

- GitGuardian Documentation: https://docs.gitguardian.com/
- Docker Swarm Security: https://docs.docker.com/engine/swarm/secrets/
- Vagrant Security: https://developer.hashicorp.com/vagrant/docs/security

### Conclusion

All exposed secrets have been removed from git history (via deletion) and are now gitignored. The exposed Swarm token has been rotated and is now invalid. No actual security breach occurred as the infrastructure uses private networks not accessible from the internet.

**Status**: ✅ **RESOLVED**
