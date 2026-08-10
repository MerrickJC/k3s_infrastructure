# Deployment
I have tried to make setup and configuration as fool-proof as possible. In doing so, I have automated several things and tried to achieve an almost entirely declarative GitOps setup. 

## Rant
I hate when you can't tell what is happening. Trying to reason about cloud systems sucks enough as it is, but not knowing what services have been applied and how things are running makes it a living hell.

I have inadvertently created something that an AI agent can probably read and reason about quite easily. Apart from the initial cluster setup, everything else is defined here in this code somewhere. That means if you point an AI at it and ask for guidance it can probably come up with something logical since it can see the whole picture.

## Design Goals
The team members in MMS who can code are basically all robotics engineers, not cloud engineers. This allows the team to build a good race car, but means that the team lacks knowledge in some other areas of software engineering and development. So the goal is to make a cloud system that is:
- easy to navigate and understand
- self-managing

MMS may or may not have long-term reliable cloud platforms to deploy on. This poses a potential issue long-term, since the team may need to decomision the servers that the ROS bag database is running on. In all likelihood, a system that is no longer running will be left unmaintained for years and then eventually will need to be redeployed. At this point, the original developers have left and the team needs to be able to redeploy with minimal effort. Having a GitOps based declarative setup should make redeploying easy. On top of this, it should make lift-and-shift deployments (moving the entire system from one place to another)  simpler, because the entire system can be spun up and shutdown in a simple way using what is already in the git repository.

## Achieving This
To achieve this setup, the cluster is managed using ArgoCD. ArgoCD allows for the automated creation of applications based on a git repository and will monitor the repository over time, updating the cluster as changes are made. It keeps track of variations of the state of the cluster from the desired state and provides an intuitive visualisation of this.