# Kubernetes Commandline
```kubectl``` is the standard commandline tool used to access kubernetes and visually inspect resources, etc. You will need kubectl at times to debug the cluster.

There are two ways of accessing kubectl.

## 1. SSH Into The Cluster Node
You can SSH directly into any node acting as a server (not an agent) for the cluster and use the built-in Kubectl commandline tool that comes with K3s. Extra security will need to be added to ensure this is still secure.

## 2. Connect Remotely To Kubernetes API
You can connect remotely to the Kubernetes API using a local kubectl installation. I am going to assume you are on Linux. 

### Prerequisites
To do this, you will need to have installed the following:
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [krew](https://krew.sigs.k8s.io/docs/user-guide/setup/install/)

You can verify installation by ensuring that you can run ```kubectl krew --help``` and having it return the manual's help page.

### Setup

After installing the above  you will need to run the following commands
```
kubectl krew install oidc-login
```

The cluster's API server is configured to require an OIDC login (through Dex) for `kubectl` access. See [oidc-cluster-authentication.md](./oidc-cluster-authentication.md) for how to log in and what access you'll get.

