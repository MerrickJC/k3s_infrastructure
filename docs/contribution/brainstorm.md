# My Contribution
I want to create


In a completely ideal scenario I want to create a system architecture which uses a 


## MMS Implementation Challenges
### Self-Hosting
- can't build a cluster at Monash because this will violate Monash rules around cybersecurity
- people might have old computers that they are willing to donate to the cause, but these are highly dispersed geographically and likely with low reliability internet connections between them

### Storage
- can't afford to store data anywhere other than the Monash server because the team generates around 1TB of bags per year.


# Three Different Architectures For MMS
Below is a comparison of different deployment architectures that MMS could utilise to run this tool

## Entirely Self-Hosted
### Pros
- no ongoing costs makes the solution cheap
- no surprise costs makes the solution safe
- could re-index large amounts of data, the only cost is time
- can utilise existing hardware, including robotics hardware that will run in production. Improves hardware integration testing

### Cons
- limited compute could make some job queues slow
- limited storage likely requires buying more physical storage devices
- can't host servers in the Makerspace
- network limitations depending on geographic spread of servers

### Achievability
An entirely self-hosted architecture would be possible, but would likely require MMS to utilise laptops and devices running in people's personal houses. This isn't ideal, as it shifts operational costs to team members as well as creating security risks when running software on people's personal home networks. It would likely require purchasing large amounts of physical storage devices, as the team is unlikely to already own the TB of storage required. Additionally, running on unreliable home networks would likely require significant data replication to avoid data loss and system outages due to one person's poor network.


## Hybrid-Cloud Architecture
The most feasible hybrid-cloud architecture would involve local compute but cloud storage

### Pros
- scalable, fast, reliable, redundant, accessible storage
- don't have to do either of:
    - develop a scaling strategy for servers
    - pay for underutilised servers
- can utilise existing compute hardware, including robotics hardware that will run in production. Improves hardware integration testing

### Cons
- ongoing costs for:
    - storage (per GB)
    - data transferred out of storage (per GB)
    - number of queries performed on storage (per GB)
- surprise costs if people do things without understanding their actions
- can't re-index large amounts of data without prohibitively expensive data egress costs for sending data via the internet from the cloud storage. A cache wouldn't help here since you would need to transfer every single GB of data that you plan to re-index, with the exception of whatever is in the cache. If the cache is 500GB but you want to reindex 1,000GB, you still need to pay for egress of 500GB

### Achievability
Could be achieved, but would need to carefully consider data analysis actions that involve transferring large amounts of data from the cloud to a local server. If you had some suitably sized caches that could accomodate majority of the data analysis actions that you intended to perform, then this wouldn't be a terrible approach.


## Entirely Cloud Architecture
### Pros
- low latency connecting compute to storage
- no egress costs for reading data from storage (assuming compute in the same region as storage)
- highly scalable storage and compute
- likely significantly faster networks than achievable on MMS's budget

### Cons
- expensive storage and compute costs
- high likelihood of surprise costs due to launching too many jobs
- reduced incentive for developers to do bag testing due to the high per-run cost
- can't test algorithms on the same devices that they will eventually run on, unless that device is available through cloud providers

## Hybrid-Cloud Architecture With Intelligent Storage Tiering

Could potentially try to get a cloud storage sponsorship, but the biggest challenge will be egress.




# Overall Thoughts
In an entirely cloud based architecture, it doesn't make sense to bother with any of the data locality aware caching, because the time taken to copy data within the data centre is so negligible that its pointless.

In an entirely self-hosted architecture, the data locality aware caching is only important if the network is slow or unreliable. If the network is slow, downloading large files will take unreasonable amounts of time. If containers request resources, are allocated those resources, but then spend time waiting for network-limited file downloads prior to running algorithms, then the allocated resources are wasted while the container is blocked waiting for the file to transfer. Deleting this file immediately if it is about to be reused would be incredibly wasteful of network resources and would take more time. This all hinges on the network being inefficient.

The main reason you need data locality aware scheduling is for ROS re-simulation, since you want to guarantee that a bag is on the device prior to starting the ROS bag replay or else the replay will fail, since "The mcap info command requires only two seeks: first to the footer..." (see https://foxglove.dev/blog/mcap-vs-ros1-bag-index-performance, viewed: 27/07/2026) but the footer is "the last record before the trailing magic bytes" (see https://mcap.dev/spec, viewed: 27/07/2026).



# Current Thoughts
A hybrid-cloud approach where you assume that everything is in the cloud except for a few edge nodes. This situation represents paying for a cloud provider and utilising their compute and storage for most things, however you still want to perform hardware verification to validate that algorithms will perform as expected on the hardware that they will be deployed on. This is a reasonable approach, because it considers the scenario where you have a data centre (which could be self-hosted/on premise or a cloud provider) which has fast, cheap internal data transfer, but you also have some edge devices that need more carefully managed and cached data transfer. Transferring to the edge devices for verification is important, but incurs a cost associated with data egress. This means these nodes are reserved for essential workloads, or can be utilised for situations where they already have data cached locally to assist other nodes.





# TODO: need to look into whether Hardware-In-The-Loop robotics systems already exist which can do the above