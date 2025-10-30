# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile for Names Manager - Docker Swarm Setup
# Defines two VMs: swarm-manager and swarm-worker

Vagrant.configure("2") do |config|
  # Manager Node Configuration
  config.vm.define "manager" do |manager|
    manager.vm.box = "bento/ubuntu-22.04"
    manager.vm.hostname = "swarm-manager"
    
    # Private network for inter-VM communication
    manager.vm.network "private_network", ip: "192.168.56.10"
    
    # Port forwarding: host:8080 -> guest:80 (frontend)
    manager.vm.network "forwarded_port", guest: 80, host: 8080
    
    # VirtualBox provider settings
    manager.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "names-manager"
    end
    
    # Docker installation provisioning (Task 1.3)
    # manager.vm.provision "shell", path: "vagrant/install-docker.sh"
  end
  
  # Worker Node Configuration
  config.vm.define "worker" do |worker|
    worker.vm.box = "bento/ubuntu-22.04"
    worker.vm.hostname = "swarm-worker"
    
    # Private network for inter-VM communication
    worker.vm.network "private_network", ip: "192.168.56.11"
    
    # VirtualBox provider settings
    worker.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "names-worker"
    end
    
    # Docker installation provisioning (Task 1.3)
    # worker.vm.provision "shell", path: "vagrant/install-docker.sh"
  end
end
