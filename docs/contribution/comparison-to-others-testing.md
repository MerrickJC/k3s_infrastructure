# A Practical Comparison Of My Tool With Existing Tools
All testing is done on a limited scale due to the hardware available

## Kleinkram
I should probably try to use the same S3-like storage when I compare my tool to Kleinkram, or else there may be performance differences between what I choose and what it chooses. I don't think that the specific choice of S3-like storage should be the reason one tool wins over others, given that S3-like storage is supposed to be easy to swap out


### 1. Parallelism
#### Description
This experiment compares the time taken to analyse 10 ROS bags in a one and two node setup. It is assumed that testing at these scales will provide a benchmark for scaling up to larger numbers of nodes. The goal of this test is to compare how well each tool runs jobs in parallel and shares resources.

#### Execution
Both tools are using the same ROS bags and the same Python script to produce a graph of vehicle speed over time for each ROS bag.

#### Expected Result
The tool I have created should concurrently allocate all jobs. My tool should complete all scripts quicker than Kleinkram since the Kleinkram has concurrency set to 1 (see line 82 of queueConsumer/src/actions/action-queue-processor.provider.ts) in its repository. This may not be a fair test, so I may need to adjust the concurrency limit in Kleinkram, although I have no clue how it will behave functionally when I adjust this.


### 2. Edge Node Re-Simulation (Download Speed)
#### Description
This experiment compares the time taken for each tool to run ROS re-simulations. The goal is to observe whether one tool is better than the other at scheduling containers, downloading ROS bags, and running the ROS re-simulations.

#### Execution
Run 10 ROS re-simulations on one and two edge nodes using 10 different ROS bags. The ROS re-simulation should not be so intensive that it causes throttling or the containers to crash. Assume that the containers being used for re-simulation are pre-made and identical across both tools.

#### Expected Result
Results for both tools should be about the same since they both have to download the data and won't have any cache hits.


### 3. Edge Node Re-Simulation (Cache Success)
#### Description
Similar to experiment 2 except this experiment compares the time taken for each tool to run ROS re-simulations using the same bags. The goal is to observe whether one tool is better than the other at scheduling containers, downloading ROS bags, caching them, and running the ROS re-simulations.

#### Execution
Run 10 ROS re-simulations on one and two edge nodes using 2 different ROS bags. The ROS re-simulation should not be so intensive that it causes throttling or the containers to crash. Assume that the containers being used for re-simulation are pre-made and identical across both tools.

#### Expected Result
My tool should be significantly faster than Kleinkram, since my tool will cache the ROS bags the first time they are downloaded and won't need to then re-download them.