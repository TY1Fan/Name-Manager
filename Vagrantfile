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
  
  # Optional: k3s Agent (Worker Node)
  # Uncomment the section below if you want a multi-node cluster
  # You'll need to join this agent to the server using a token
  
  # config.vm.define "k3s-agent", autostart: false do |agent|
  #   agent.vm.hostname = "k3s-agent"
  #   agent.vm.network "private_network", ip: "192.168.56.11"
  #   
  #   agent.vm.provider "virtualbox" do |vb|
  #     vb.name = "k3s-agent"
  #     vb.memory = "2048"
  #     vb.cpus = 2
  #   end
  #   
  #   # Agent will need to join the server using K3S_TOKEN and K3S_URL
  #   # agent.vm.provision "shell", inline: <<-SHELL
  #   #   curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.10:6443 K3S_TOKEN=<token> sh -
  #   # SHELL
  # end
end
