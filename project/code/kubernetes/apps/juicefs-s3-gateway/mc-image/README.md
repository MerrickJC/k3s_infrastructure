# MC Image

## Problem

JuiceFS uses a fork of MinIO as part of its core logic. MinIO is no longer open source and has archived almost everything, which means that you can't directly pull the Docker images since they have been deleted from Docker Hub. On top of this, JuiceFS requires a specific MinIO version to be able to setup IAM policies correctly.

## Solution

We build the Docker image ourselves (see [Dockerfile](./Dockerfile)) using one of the released binaries (which is still available online) pinned to the specific version we require. This should only need to be done once, so isn't massively automated.

### Steps

1. Generate a CLI key for the self-hosted Zot container registry (Login to Zot -> click profile picture -> click "API Keys" -> click "Create New API Key") and put this in [password.txt](./password.txt)
2. Update the username in the [build.sh](./build.sh) to be the email Zot has recorded as your username (Login to Zot -> click profile picture to see email)
3. [OPTIONAL] Update the image tag in [build.sh](./build.sh) and the [juicefs-gateway-iam-job](../secrets/juicefs-gateway-iam-job.yaml) if required
4. Run [build.sh](./build.sh) locally and the image should build and publish to the container registry
