Vagrant.configure("2") do |config|

    config.vm.define "controlplane" do |server|
      server.vm.box = "ubuntu/bionic64"
      server.vm.hostname = "controlplane"
      server.vm.network "private_network", ip: "192.168.50.22"
      server.vm.provision "shell", path: "setup_kubernetes_control_plane.sh", args: "192.168.50.22"
      server.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', '2048']
      end
    end

    config.vm.define "worker" do |server|
      server.vm.box = "ubuntu/bionic64"
      server.vm.hostname = "worker"
      server.vm.network "private_network", ip: "192.168.50.23"
      server.vm.provision "shell", path: "setup_kubernetes_worker.sh", args: "192.168.50.23"
      server.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', '2048']
      end
    end

    config.vm.define "worker2" do |server|
      server.vm.box = "ubuntu/bionic64"
      server.vm.hostname = "worker2"
      server.vm.network "private_network", ip: "192.168.50.24"
      server.vm.provision "shell", path: "setup_kubernetes_worker.sh", args: "192.168.50.24"
      server.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--memory', '2048']
      end
    end
 
    config.vm.define "ingress" do |server|
      server.vm.box = "ubuntu/bionic64"
      server.vm.hostname = "ingress"
      server.vm.network "private_network", ip: "192.168.50.21"
      server.vm.provision "shell", path: "setup_ingress_controller.sh"
    end
   
  end
  