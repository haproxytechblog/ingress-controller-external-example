# HAProxy Kubernetes Ingress Controller run Externally (Outside Kubernetes)

This test lab demonstrates how to run the ingress controller outside of your Kubernetes cluster
and use Calico in BGP peering mode to share routes to the pod ClusterIPs with it.

## About this test lab:

Virtual machines include:

* ingress: the HAProxy ingress controller and the Bird router
* controlplane: The Kubernetes control plane node
* worker: A Kubernetes worker node
* worker2: Another Kubernetes worker node

## Try it out

1. Create the VMs by using Vagrant:

```
$ vagrant up
```

1. Once the VMs are up, SSH into the *controlplane* node. This is the 
   node that hosts the Kubernetes API.

```
$ vagrant ssh controlplane
```

1. Check that all nodes are up and that networking is also up:

```
$ kubectl get nodes

NAME           STATUS   ROLES                  AGE     VERSION
controlplane   Ready    control-plane,master   4h7m    v1.21.1
worker         Ready    <none>                 4h2m    v1.21.1
worker2        Ready    <none>                 3h58m   v1.21.1

$ sudo calicoctl node status

Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+--------------------------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |              INFO              |
+---------------+-------------------+-------+----------+--------------------------------+
| 192.168.50.21 | global            | start | 00:10:03 | Active Socket: Connection      |
|               |                   |       |          | refused                        |
| 192.168.50.23 | node-to-node mesh | up    | 00:16:11 | Established                    |
| 192.168.50.24 | node-to-node mesh | up    | 00:20:08 | Established                    |
+---------------+-------------------+-------+----------+--------------------------------+

IPv6 BGP status
No IPv6 peers found.
```

Note that BGP peering with 192.168.50.21 (the ingress node) is not yet working.

1. Get the IP subnets assigned to each node:

```
$ kubectl describe blockaffinities | grep -E "Name:|Cidr:"

Name:         controlplane-172-16-49-64-26
  Cidr:     172.16.49.64/26
Name:         worker-172-16-171-64-26
  Cidr:     172.16.171.64/26
Name:         worker2-172-16-189-64-26
  Cidr:     172.16.189.64/26
```

1. Edit the file **bird.conf**, adding the IP ranges to the `protocol bgp` sections:

```
# controlplane
protocol bgp {
  	local 192.168.50.21 as 65000;
	neighbor 192.168.50.22 as 65001;
    import filter {
	  if net = 172.16.49.64/26 then accept;
    };
    export none;
}

# worker
protocol bgp {
  	local 192.168.50.21 as 65000;
	neighbor 192.168.50.23 as 65001;
    import filter {
	  if net = 172.16.171.64/26 then accept;
    };
    export none;
}

# worker2
protocol bgp {
  	local 192.168.50.21 as 65000;
	neighbor 192.168.50.24 as 65001;
    import filter {
	  if net = 172.16.189.64/26 then accept;
    };
    export none;
}
```

1. Copy **bird.conf** to **/etc/bird/** on the *ingress* VM. Then, restart Bird.

```
$ sudo cp /vagrant/bird.conf /etc/bird/
$ sudo systemctl restart bird
```

1. Run `birdc show protocols` and see that Bird has established BGP peering with the 
   three Kubernetes nodes (bgp1, bgp2, and bgp3):
  
```
$ sudo birdc show protocols

BIRD 1.6.8 ready.
name     proto    table    state  since       info
bgp1     BGP      master   up     18:38:03    Established   
bgp2     BGP      master   up     18:38:04    Established   
kernel1  Kernel   master   up     18:38:02    
device1  Device   master   up     18:38:02    
```

1. Run `birdc show route protocol` on each peer to see the routing information:

```
$ sudo birdc show route protocol bgp1

BIRD 1.6.8 ready.
172.16.171.64/26   via 192.168.50.23 on enp0s8 [bgp1 18:38:04] * (100) [AS65001i]

$ sudo birdc show route protocol bgp2

BIRD 1.6.8 ready.
172.16.189.64/26   via 192.168.50.24 on enp0s8 [bgp2 18:38:04] * (100) [AS65001i]
```

1. You can also check the server's route table:

```
$ route

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         _gateway        0.0.0.0         UG    100    0        0 enp0s3
10.0.2.0        0.0.0.0         255.255.255.0   U     0      0        0 enp0s3
_gateway        0.0.0.0         255.255.255.255 UH    100    0        0 enp0s3
172.16.49.64    192.168.50.22   255.255.255.192 UG    0      0        0 enp0s8
172.16.171.64   192.168.50.23   255.255.255.192 UG    0      0        0 enp0s8
172.16.189.64   192.168.50.24   255.255.255.192 UG    0      0        0 enp0s8
192.168.50.0    0.0.0.0         255.255.255.0   U     0      0        0 enp0s8
```

1. Run `calicoctl node status` on the *controlplane* VM and see that all BGP peers are now established.

```
$ sudo calicoctl node status
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 192.168.50.21 | global            | up    | 00:32:13 | Established |
| 192.168.50.23 | node-to-node mesh | up    | 00:16:12 | Established |
| 192.168.50.24 | node-to-node mesh | up    | 00:20:09 | Established |
+---------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

1. Deploy some pods and create an Ingress:

```
$ kubectl apply -f /vagrant/app.yaml
```

1. Then, check which ClusterIP addresses each pod was given:

```
$ kubectl get pods -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP              NODE      NOMINATED NODE   READINESS GATES
app-8cfdf9959-5rtdq   1/1     Running   0          20s   172.16.171.67   worker    <none>           <none>
app-8cfdf9959-gtqj9   1/1     Running   0          20s   172.16.171.65   worker    <none>           <none>
app-8cfdf9959-mt747   1/1     Running   0          20s   172.16.189.66   worker2   <none>           <none>
app-8cfdf9959-r985c   1/1     Running   0          20s   172.16.171.66   worker    <none>           <none>
app-8cfdf9959-t7qwn   1/1     Running   0          21s   172.16.189.65   worker2   <none>           <none>
```

1. From the *ingress* VM, you can reach any of these pod IP addresses:

```
$ sudo apt install -y traceroute

$ traceroute 172.16.171.67

traceroute to 172.16.171.67 (172.16.171.67), 30 hops max, 60 byte packets
 1  192.168.50.23 (192.168.50.23)  4.799 ms  3.192 ms  2.894 ms
 2  172.16.171.67 (172.16.171.67)  2.669 ms  3.916 ms  3.875 ms
```

1. Start the ingress controller:

```
$ sudo systemctl enable haproxy-ingress
$ sudo systemctl start haproxy-ingress
```

1. Add an entry to the **/etc/hosts** file on your host machine that maps
   *test.local* to the *ingress* VM's IP address:

```
192.168.50.21 test.local
```

1. Open **test.local** in your browser, or **test.local:1024** to see the HAProxy 
   Stats page.