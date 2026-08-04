# How To Keep Things Free For MMS
Assume that MMS can run a few servers somewhere. For example, these could be part of the Oracle always-free tier (which offers an ARM 2-core 12GB RAM server for free). These central servers are responsible for running the core services, including the postgres database, 

Running ROS simulations is compute intensive. The team will need to setup servers somewhere which they can run simulations on. This could be self-hosted servers running somewhere that the team is approved to put servers (i.e. not hosting them at uni, probably hosting them at someone's house) or could be cloud hosted servers.


## Cloud-Based Analytics
Data analysis can be done cheaper. If the team is willing to experiment, it is highly likely that a cloud setup could be created which costs the team maybe a few dollars per month. This could be done in a safely in multiple ways. My first thought is to use AWS (I am biased towards AWS as it is the cloud platform which I have the most experience with). Assume that there are 2 developers per year that are willing to donate their AWS free trial to the team. The AWS free trial currently provides $200 USD credit ($100 up front and you can complete tasks to get an extra $100) to be used within 6 months. 2 developers means the team gets an entire year of coverage and around ~$400 USD per year to experiment with. This should mean that the team can run a cloud-based analytics platform for zero out-of-pocket cost.

The setup I am invisiging would utilise AWS Lambda to stream ROS bags from wherever they are stored and compute metrics as needed. The AWS Lambda free tier includes: 1,000,000 free requests per month; and up to 400,000 GB-seconds or 3.2 million seconds of compute time per month. If you assume that the team uses a 2GB RAM lambda function to run analysis scripts, the team could perform 200,000 seconds of data analysis. That is around 55.6 hours of data analysis.

There are two conflicting ideologies that can be employed here. If data transfer from wherever the ROS bags are stored into AWS Lambda can be done quickly, then the team can afford to just download each ROS bag during the Lambda function's invocation. AWS Lambda does not have data ingress costs, but the team will have to pay for the longer running time of the Lambda function as a result of the network throughput. Alternatively, if network throughput is infeasibly slow, the team could load data in S3 prior to data analysis. This would mean that the Lambda functions can complete much quicker without network latency, but at the expense of having to pay for cloud storage. This cloud storage comes at a cost of USD $0.025 per GB per month. AWS S3 also has associated API costs, but these are USD $0.0055 per 1000 requests, so the cost will be negligible compared to the storage cost itself. The team could choose to utilise S3 for all ROS bag storage. If you assume the team generates around 1TB of bags per year and stores around 5 years worth of ROS bags, that equates to 5TB of ROS bags. 5000 GB * $0.025 * 12 months = $1500 USD per year to store ROS bags. That is likely infeasible for the team to sustain. A more suitable alternative might be that the team stores ROS bags in its own location, (i.e. continues to use the Monash server) and only stores some ROS bags in S3. In this way, S3 acts like a cache layer for running cloud computation. Storing a single year of ROS bags would come to around $300 USD per month.

The team could utilise AWS entirely for simulation. Running an "M5 General Purpose Extra Large" EC2 instance with 16GiB RAM and 4 vCPU would cost USD $0.0663 hourly (at average spot pricing for Sydney accoridng to https://instances.vantage.sh/).

In a somewhat ideal setup, the team would have several people donate their AWS free trials to the team per year. Each year the setup would include the following people:
- 2 accounts for S3 storage + lambda functions
- 2 accounts for EC2

The setup would include one person having an S3 bucket storing 

Assume that the team wants to run x number of ROS bag re-simulations per day. Each ROS bag runs for 260 seconds and the container needs 40 seconds to start up and shut down. This means the team needs 300x seconds of EC2 runtime per day. 300x /60 /60 *0.0663 = $0.005525x daily. Assume 365 days of development per year and assume 2 accounts with $200 USD credit each. That means the team has 400/365 = 0.005525x. x = 400 /365 /0.005525 = ~198. Using this model, the team could afford to run 198 ROS bag re-simulations per day for an entire year. Alternatively, if you assume the team is only operational for 3/4 of the year (around 270 days e.g. due to weekends, exams, etc), then that's 268 ROS bag replays per day. There are likely other associated costs that I'm not accounting for accurately in this model, such as storage mounted to the EC2 instances, but this provides a benchmark for what is possible. This setup assumes that a docker image already exists for the jobs being run on EC2. If a Docker image still needs to be built in order to run the cloud jobs then that time needs to be factored in as well.

It is (apparently) possible to use KEDA (Kubernetes Event-Driven Autoscaling) to run a self-hosted cluster which scales up using cloud resources.



Could setup a local cluster running somewhere (e.g. someone's house) which can run simple jobs. When something requiring more resources than the simple cluster can handle 



## Oracle Cloud setup
I think that Oracle cloud is the way to go. Oracle's free tier offers "1,500 OCPU hours and 9,000 GB hours per month" of always free usage. If you strictly use the free tier, you can provision a 2 OCPU, 12GB RAM server to run forever for completely free. While this is useful for small tasks, it does not allow for full ROS re-simulation, as there are not enough resources. Instead, if you switch to the Pay-As-You-Go (PAYG) account type, then you still maintain all of the always free tier benefits, but you can provision servers with more OCPU and RAM. Provided that you don't exceed the monthly allowance of 1,500 OCPU hours and 9,0000 GB hours, then you will not pay anything for the usage. 

I propose that MMS utilises several team members' accounts to setup a cluster. One account should act as the control plane for the Kubernetes cluster while the other accounts act as workers. The control plane should run 24/7 with 2 OCPU and 12GB RAM. It will run the kubernetes control plane services and some other services that the team wants running 24/7. Other team members can then use their accounts for burstable compute. If you assume that the team needs a 8 OCPU, 32GB RAM device to run ROS re-simulation, then the team could run a VM of this spec for 187.5 hours (7.8 days) per month using 1 account (this is on top of the 1 control plane account, making a total of 2 accounts). Assume that ROS bags run for 260 seconds, take 60 seconds to copy and the VM takes 60 seconds to provision. That means that the team could run around 1776 ROS bag re-simulations per free tier account. This does not account for docker container build time, but another VM could be privisioned for this


Could setup a Dynamic Routing Gateway to allow VMs running in multiple team members' accounts to connect without causing data egress. This preserves data egress limits to allow for things like team members download ROS bags.

Assume that Autonomous Systems has 10 members willing to donate their Oracle free tier account. Each team member gets a 200GB boot drive for free. Assume that the OS and other stuff uses around 50GB, that means the team would have around 1.5TB of storage for free. Cluster together the 