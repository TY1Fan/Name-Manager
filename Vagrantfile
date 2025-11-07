# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile for Names Manager - k3s (Lightweight Kubernetes) Setup
# Defines k3s-server VM for single-node cluster

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  
  # k3s Server (Control Plane + Worker)
  config.vm.define "k3s-server" do |server|
    server.vm.hostname = "k3s-server"
    
    # Private network for cluster communication
    server.vm.network "private_network", ip: "192.168.56.10"
    
    # Port forwarding for kubectl access from laptop
    # Forward host:6443 -> guest:6443 (k3s API server)
    server.vm.network "forwarded_port", guest: 6443, host: 6443
    
    # Port forwarding for accessing NodePort services
    # Forward host:30080 -> guest:30080 (typical NodePort range 30000-32767)
    server.vm.network "forwarded_port", guest: 30080, host: 30080
    
    # VirtualBox provider settings
    server.vm.provider "virtualbox" do |vb|
      vb.name = "k3s-server"
      vb.memory = "4096"  # 4GB recommended for k3s + applications
      vb.cpus = 2
    end
    
    # Install k3s (latest stable version)
    server.vm.provision "shell", inline: <<-SHELL
      # Update system
      apt-get update
      
      # Install k3s
      echo "Installing k3s..."
      curl -sfL https://get.k3s.io | sh -
      
      # Wait for k3s to be ready
      echo "Waiting for k3s to be ready..."
      sleep 15
      
      # Check k3s status
      systemctl status k3s --no-pager
      
      # Verify k3s installation
      echo "Verifying k3s installation..."
      /usr/local/bin/k3s kubectl get nodes
      
      # Make kubeconfig accessible to vagrant user
      mkdir -p /home/vagrant/.kube
      sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
      sudo chown vagrant:vagrant /home/vagrant/.kube/config
      
      echo "k3s installation complete!"
      echo "Cluster Info:"
      /usr/local/bin/k3s kubectl cluster-info
    SHELL
  end
  
  # k3s Agent (Worker Node) - Multi-node cluster
  config.vm.define "k3s-agent", autostart: false do |agent|
    agent.vm.hostname = "k3s-agent"
    agent.vm.network "private_network", ip: "192.168.56.11"
    
    agent.vm.provider "virtualbox" do |vb|
      vb.name = "k3s-agent"
      vb.memory = "2048"  # 2GB for worker node
      vb.cpus = 2
    end
    
    # Join k3s cluster as agent (worker node)
    agent.vm.provision "shell", inline: <<-SHELL
      # Update system
      apt-get update
      
      # Install k3s agent
      echo "Installing k3s agent and joining cluster..."
      curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN=K106c3fe74780453adbdcbe3a2111afbdfd22aabc60a349f7bc34f547b95aca41bf::server:cc15013299efec07ab51a374f3de5eac sh -
      
      # Wait for agent to join
      echo "Waiting for agent to join cluster..."
      sleep 15
      
      # Check k3s-agent service status
      systemctl status k3s-agent --no-pager
      
      echo "k3s agent installation complete!"
    SHELL
  end
end
