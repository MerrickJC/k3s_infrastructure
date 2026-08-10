# In Scope
- Kubernetes scalability will only be provided for OpenStack, but the components used for this will be modular and replacable
- Deploying onto an OpenStack cluster (ARDC Nectar)
- HTTP gateways/endpoints will be configured using OpenStack setup and may differ from other cloud providers

# Out Of Scope
- The choice of S3-like object storage. It is assumed that whoever deploys this overall tool will make their own selection for an S3-like object storage. The specific choice of an S3-like object storage does not impact the configuration of the rest of the architecture, since the S3-like API is abstracted by JuiceFS
- Kubernetes scalability will not be provided for non-OpenStack cloud providers, but the design will be modular enough that alternatives could be utilised as a drop-in replacement
