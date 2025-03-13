# Configuring complex inputs for VSI in IBM Cloud projects
Several optional input variables in the VSI [deployable architecture](https://cloud.ibm.com/catalog#deployable_architecture) use complex object types. You specify these inputs when you configure your deployable architecture.

- [Security Group](#options-with-security-group) (`security_group`)
- [Block Storage Volumes](#options-with-block-volumes) (`block_storage_volumes`)
- [Load Balancers](#options-with-load-balancers) (`load_balancers`)
- [Secondary Security Groups](#options-with-secondary-security-groups) (`secondary_security_groups`)


## Options with Security Group <a name="options-with-security-group"></a>

The `security_group` input variable allows you to provide of a security group which needs to be created for VSI.

- Variable name: `security_group`.
- Type: A object. Allows only one object representing a security group
  - `name` (required): The name of the security group
  - `rules` (required): (List) The list of rules for the security group
      - `name` (required): The name of the rule.
      - `direction` (required): The direction of the traffic either `inbound` or `outbound`.
      - `source`(required): Security group ID, an IP address, a CIDR block, or a single security group identifier.
      - `tcp`(optional): (List) A nested block describes the tcp protocol of this security group rule.
        - `port_max`(required): The TCP port range that includes the maximum bound. Valid values are from 1 to 65535.
        - `port_min`(required): The TCP port range that includes the minimum bound. Valid values are from 1 to 65535.
      - `udp`(optional): (List) A nested block describes the udp protocol of this security group rule.
        - `port_max`(required): The UDP port range that includes maximum bound. Valid values are from 1 to 65535.
        - `port_min`(required): The UDP port range that includes minimum bound. Valid values are from 1 to 65535.
      - `icmp`(optional): (List) A nested block describes the icmp protocol of this security group rule.
        - `type`(required): The ICMP traffic type to allow. Valid values from 0 to 254.
        - `code`(required): The ICMP traffic code to allow. Valid values from 0 to 255.
- Default value: null


### Example Rule For Security Group Configuration

```hcl
security_group = {
  name = "example-sg"
  rules = [{
    name      = "example-rule"
    direction = "inbound"
    source    = "196.0.0.1"
    tcp = {
      port_max = 200
      port_min = 100
    }
  }]
}
```


## Options with Block Storage Volumes <a name="options-with-block-volumes"></a>

The `block_storage_volumes` input variable allows you to provide of a List describing the block storage volumes that will be attached to each VSI.

- Variable name: `block_storage_volumes`.
- Type: A list of objects.
  - `name` (required): The name of the block storage volume.
  - `profile` (required): The profile to use for this volume.
  - `capacity` (optional): The capacity of the volume in gigabytes. This defaults to 100.
  - `iops` (optional): The total input/ output operations per second (IOPS) for your storage. This value is required for custom storage profiles only.
  - `encryption_key`(optional): The key to use for encrypting this volume.
  - `resource_group_id`(optional): The resource group ID for this volume.
  - `snapshot_id`(required): The ID of snapshot from which to clone the volume.
  - `tags`(required): (List) A list of user tags that you want to add to your volume. (https://cloud.ibm.com/apidocs/tagging#types-of-tags)
- Default value: An empty list ([]).


### Example Rule For Block Storage Volumes Configuration

```hcl
block_storage_volumes = [{
    name    = var.prefix
    profile = "10iops-tier"
}]
```


## Options with Load Balancers <a name="options-with-load-balancers"></a>

The `load_balancers` input variable allows you to provide of a list Load balancers to add to VSI. **Important** This load balancer will only have a single VSI has its backend pool member.

- Variable name: `load_balancers`.
- Type: A list of objects.
  - `name` (required): The name of the VPC load balancer.
  - `type` (required): (List) The type of the load balancer. Default value is public. Supported values are `public` and `private`.
  - `listener_port` (optional): (number) The listener port number. Valid range 1 to 65535.
  - `listener_port_max` (optional): (number) The inclusive upper bound of the range of ports used by this listener.
  - `listener_port_min` (optional): (number) The inclusive lower bound of the range of ports used by this listener.
  - `listener_protocol` (required): The listener protocol. Enumeration type are `http`, `tcp`, `https` and `udp`. Network load balancer supports only `tcp` and `udp` protocol.
  - `connection_limit` (optional): (number) The connection limit of the listener. Valid range is 1 to 15000. Network load balancer do not support connection_limit argument.
  - `idle_connection_timeout` (optional): (number) The idle connection timeout of the listener in seconds. Supported for load balancers in the application family. Default value is 50, allowed value is between 50 - 7200.
  - `algorithm` (required):  The load-balancing algorithm. Supported values are `round_robin`, `weighted_round_robin`, or `least_connections`.
  - `protocol` (required):  The pool protocol. Enumeration type: `http`, `https`, `tcp`, `udp` are supported.
  - `health_delay` (required): (number) The health check interval in seconds. Interval must be greater than timeout value.
  - `health_retries` (required): (number) The health check max retries.
  - `health_timeout` (required): (number) The health check timeout in seconds.
  - `health_type` (required): The pool protocol. Enumeration type: `http`, `https`, `tcp` are supported.
  - `pool_member_port` (required): The port number of the application running in the server member.
  - `profile` (optional): For a Network Load Balancer, this attribute is required and should be set to `network-fixed`. For Application Load Balancer, profile is not a required attribute.
  - `accept_proxy_protocol` (optional): (bool) If set to true, listener forwards proxy protocol information that are supported by load balancers in the application family. Default value is false.
  - `subnet_id_to_provision_nlb` (optional): Required for Network Load Balancer. If no value is provided, the first one from the VPC subnet list will be selected.
  - `dns` (optional): (Object) The DNS configuration for this load balancer.
    - `instance_crn` (required): The CRN of the DNS instance associated with the DNS zone
    - `zone_id` (required): The unique identifier of the DNS zone.
  - `security_group` (optional): (List) A list of security groups to use for this load balancer. This option is supported for both application and network load balancers.
    - `name` (required): The name of the security group
    - `rules` (required): (List) The list of rules for the security group
        - `name` (required): The name of the rule.
        - `direction` (required): The direction of the traffic either `inbound` or `outbound`.
        - `source`(required): Security group ID, an IP address, a CIDR block, or a single security group identifier.
        - `tcp`(optional): (List) A nested block describes the tcp protocol of this security group rule.
          - `port_max`(required): The TCP port range that includes the maximum bound. Valid values are from 1 to 65535.
          - `port_min`(required): The TCP port range that includes the minimum bound. Valid values are from 1 to 65535.
        - `udp`(optional): (List) A nested block describes the udp protocol of this security group rule.
          - `port_max`(required): The UDP port range that includes maximum bound. Valid values are from 1 to 65535.
          - `port_min`(required): The UDP port range that includes minimum bound. Valid values are from 1 to 65535.
        - `icmp`(optional): (List) A nested block describes the icmp protocol of this security group rule.
          - `type`(required): The ICMP traffic type to allow. Valid values from 0 to 254.
          - `code`(required): The ICMP traffic code to allow. Valid values from 0 to 255.

- Default value: An empty list ([]).


### Example Rule For Load Balancers Configuration

```hcl
load_balancers = [
  {
    name                    = "${var.prefix}-lb"
    type                    = "public"
    listener_port           = 9080
    listener_protocol       = "http"
    connection_limit        = 100
    idle_connection_timeout = 50
    algorithm               = "round_robin"
    protocol                = "http"
    health_delay            = 60
    health_retries          = 5
    health_timeout          = 30
    health_type             = "http"
    pool_member_port        = 8080
  },
  {
    name              = "${var.prefix}-nlb"
    type              = "public"
    profile           = "network-fixed"
    listener_port     = 3128
    listener_protocol = "tcp"
    algorithm         = "round_robin"
    protocol          = "tcp"
    health_delay      = 60
    health_retries    = 5
    health_timeout    = 30
    health_type       = "tcp"
    pool_member_port  = 3120
  }
]
```

## Options with Secondary Security Groups <a name="options-with-secondary-security-groups"></a>

This variable allows you to pass details of security group IDs to add to the VSI deployment secondary interfaces (5 maximum). Use the same value for interface_name as for name in secondary_subnets to avoid applying the default VPC security group on the secondary network interface.

- Variable name: `secondary_security_groups`.
- Type: A list of objects.
  - `security_group_id` (required): The security group ID.
  - `interface_name` (required): The name of the Virtual network interface you want to attach the security group.

### Example for subnets

```hcl
secondary_security_groups = [
  {
    security_group_id  = "3451a1debe2674472817209601dde6a"
    interface_name     = "example-vni"
  },
]
```
