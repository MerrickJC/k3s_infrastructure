# Goals For MMS
MMS has access to the ARDC Nectar compute cloud on the Powerful tier (see https://support.ehelp.edu.au/support/solutions/articles/6000271206). This provides the team with 8000 Service Units (SU) per year, which is the equivalent of running a 32 vCPU, 64GB RAM (m3.xxlarge) for an entire year. The team can however run up to 128 vCPU and 256GB RAM simultaneously in bursts. Additionally, it appears that the Monash cluster supports pre-emptible (spot) instances which use 1/4 Service Units but can only last maximum 24 hours (see https://support.ehelp.edu.au/support/solutions/articles/6000255691-nectar-services-summary-list#:~:text=Preemptible%20Instances,Melbourne%2C%20QRIScloud%2C%20Tasmania, and https://support.ehelp.edu.au/support/solutions/articles/6000243910-nectar-preemptible-instance-service)
This is a good starting point for MMS to run heavy workloads.

The ARDC Nectar cluster is an implementation of an OpenStack cluster and supports OpenStack sdk and packages. I think that MMS would benefit from deploying a Kubernetes cluster on Nectar (see guide here: https://tutorials.rc.nectar.org.au/kubernetes/01-overview), since it would allow the team to efficiently run containerised services and jobs using Nectar, but more importantly would handle scaling efficiently. It would also support a GitOps approach to server management, which would improve reproducibility and ensure that the cluster does not become unmaintainable after current team members leave.

## Changes To Jenkins
Currently the team is hosting its Jenkins server on the ARDC on a 16 vCPU, 32GB RAM server (I believe, directly installed in an Ubuntu image). While this setup works fine and would continue to function for the team, it is essentially wasting service units because the Jenkins server only processes a handful of pull requests per day and sits idle for the rest of the time. I have not looked at or calculated a single number, but I would guess that Jenkins sits idle 80% of the time, especially between 12am and 8am.

I propose that MMS uses the Jenkins Kubernetes plugin to deploy Jenkins agents on Kubernetes. In this setup, Jenkins would operate a lightweight server which would orchestrate jobs to run on agents, but the built-in Jenkins agent would not run any jobs itself. The Jenkins kubernetes plugin would schedule agents to run in kubernetes, which can have resource requests as desired for that particular Jenkins pipeline. Using this setup, the Jenkins server could likely run with 2 vCPU and 4GB RAM (Gemini gave me those numbers, but honestly I believe it would be around this). MMS could then utilise an autoscaling cluster which would scale up when Jenkins tries to schedule jobs (using the Kubernetes API) and scale back down when nodes are no longer needed. This will introduce an overhead for scaling up the cluster every time that a Jenkins job is submitted, which will likely mean about a 1-2 minute delay in jobs starting. I think that this overhead is small enough compared to the regular Jenkins pipeline length to be considered negligible. Additionally, this overhead will enable massively improved parallelism, meaning that many pipeline executions could occur simultaneously with no performance degradation.

The build stage of the MMS pipeline should produce a deployable docker image. If the build stage of the MMS pipeline produces a deployable docker image, then this can be stored as an output and be used to feed into BagAnTo testing. Alternatively, BagAnTo could be integrated into Jenkins, but I think that letting BagAnTo runs handle their own orchestration without the Jenkins node supervising makes more sense. I think Jenkins should build the docker image, publish it to the container registry and then either trigger BagAnTo to start running in Parallel or else trigger it at the end of the Jenkins pipeline.


## Opinions About Jenkins
Consider me a naive outsider. I am about to write down my opinion that you didn't ask for and probably don't care about, but I was looking through Jenkins and have some opinions on the way that it is currently running.

1.
    I saw a pull request someone had made where they had made 3 commits in the span of 6 minutes and all 3 commits triggered a Jenkins pipeline. The Jenkins agent then ran all 3 commits in parallel on the 3 different executors on the built-in agent. The build time for the 3 parallel executions is almost 3 times the build time of a single execution of (almost) equivalent code.

    One non-parallel Jenkins run:
    ![One non-parallel Jenkins run](./pics/single-jenkins-run.png)

    Three parallel Jenkins runs:
    ![Three parallel Jenkins runs](./pics/triple-jenkins-run.png)

    I think that after subsequent commits that previous Jenkins runs should be automatically aborted.
    Arguments for:
    - would reduce overall Jenkins load from repetitive testing, which would speed up recent commits due to more resource availability
    - assume a full Jenkins pipeline takes 20 minutes. Committing code less than 20 minutes after the initial commit means you probably realised your previous code needed to be updated anyway and you're unlikely to need the output of a previous commit if this is the case

    Arguments against:
    - if your Jenkins pipeline execution is 99% complete but gets aborted because you committed a non-code change (e.g. added comments to a file or updated documentation). Yeah, that sucks
    - might want to revert the commit and won't know what commits are safe to revert to. I still think that if you pushed changes that close together then your code wasn't good for it in the first place

2.
    The Jenkins build doesn't seem super efficient. The "Declarative: Agent Setup" stage seems like the agent's setup should just be independent of a particular pipeline's scripts. At a quick glane, the agent setup stuff should probably be updated on a regular basis but this shouldn't happen every time a Jenkins build is launched. There should be a daily/weekly cron job which triggers updating the Jenkins agent docker image and all the other pipelines should just refer to that published docker image by tag. This would avoid some random builds having long agent setup stages when (from my understanding) it isn't relevant to the code being tested.

    Overall I think that there are other things that could be cached and reused more effectively, but again, I say this as a naive outsider that has never used colcon.