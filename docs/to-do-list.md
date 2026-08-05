# To Do List:
## Storage Setup And Testing
- [ ] Deploy PostgreSQL into Kubernetes
- [ ] Find a web-based PostgreSQL database modeller and deploy it in my cluster so that I (and people in the future) can modify the database schema
- [ ] Create preliminary Postgres schema
- [ ] Deploy the Postgres schema using a git-based migration tool
- [ ] Setup a random S3-like storage in the most basic way so that it just works
- [ ] Setup JuiceFS on top of the S3-like storage
- [ ] Setup an API framework which works locally and can accept a ROS bag as input and store it locally (work on storing to S3 later)
- [ ] Create a really basic file upload UI which routes to the API framework. Make it a static frontend so that I can later use Swift (S3-like) static site instead of needing a server
- [ ] Create a Docker build file for the backend
- [ ] Create a basic Docker build file for the frontend
- [ ] Setup a custom container registry in Kubernetes (make it quick, nothing fancy because I will use Nectar's built in container registry later)
- [ ] Setup GitHub CI/CD (or alternative) to build the frontend and backend docker containers
- [ ] Run the backend as a service in Kubernetes
- [ ] Run the frontend as a service in Kubernetes (or else figure out how to use my S3-like storage to host it)
- [ ] Configure services to be accessible outside the cluster (configure ingress into the cluster)
    - [ ] Frontend
    - [ ] ArgoCD web UI
    - [ ] Postgres modeller

## Job Setup And Testing
- [ ] Setup Argo workflows (or similar) in Kubernetes
- [ ] Create a Python function which can generate Argo workflow templates and attach this to the backend API
- [ ] Deploy the Python function in the cluster and test that it works
- [ ] Create another Python script which reads a ROS bag from local file directory and writes something about the bag to the database 
- [ ] Setup interface for ROS bag storage abstraction so that scripts access ROS bags in a simplified way
- [ ] Create a Docker image which has the Python script baked into it
- [ ] Call the API to launch the workflow using the Docker image above
- [ ] Implement a Python script state controller (e.g. Prefect)
- [ ] Create a way to configure which scipts automatically run when a ROS bag is uploaded

## ROS Re-Simulation
- [ ] Setup a Kubernetes deployed Docker image builder which outputs the result to the container registry
- [ ] Create a Docker image (or modify the existing Jenkins image) which can build MMS's codebase
- [ ] Create a workflow template which runs a ROS bag and records some sort of useful output
    - [ ] Consult MMS about what a useful ROS re-simulation would look like

## Edge Node Testing
- [ ] Setup an edge node and connect it to the cluster
    - [ ] Setup Ubuntu on the edge node
    - [ ] Setup K3s on the edge node
    - [ ] Configure a VPN or tunnel or similar for the edge node to connect to the cluster
    - [ ] Identify the edge node as an edge node
- [ ] Setup Fluid on the edge node
    - [ ] Deploy Fluid in Kubernetes
    - [ ] Setup so that new edge nodes automatically utilise Fluid

## Data Analysis
- [ ] Update the frontend to include information:
    - [ ] Summary information about ROS bags
- [ ] Update the frontend to include a way to:
    - [ ] Login
    - [ ] Run Git-owned scripts on bags
    - [ ] See the output of scripts
    - [ ] Manually run ROS re-simulation
    - [ ] Upload
        - [ ] ROS bags
        - [ ] Associated metadata
    - [ ] Download ROS bags
    - [ ] Comment on a ROS bag
    - [ ] Link an issue to multiple ROS bags
    - [ ] Link similar issues together
    - [ ] Comment on an issue
    - [ ] Create a testing session
    - [ ] Comment on a testing session
    - [ ] Create a stint
    - [ ] Comment on a stint

## Other Things
- [ ] Modify the MMS launch script to:
    - [ ] Produces a git patch file for each launch (also save the commit it branches off)
    - [ ] Scrape all parameters for each launch


# Consider Doing In The Future
- [ ] 