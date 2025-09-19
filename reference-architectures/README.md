# Reference Architectures

This directory contains reference architecture documentation for the Virtual Server Instance on VPC deployable architectures.

## Available Variations

### Fully Configurable Variation
**File:** `deploy-arch-ibm-vsi-fully-configurable.md`

The Fully configurable variation provides extensive customization options for deploying virtual servers with advanced features including:
- Multiple VSI configurations and profiles
- Load balancers with custom configurations
- Multiple block storage volumes
- Advanced networking features
- Placement groups and high availability
- Complex security group and ACL configurations

**Best for:** Production environments, complex applications requiring extensive customization, enterprise workloads with specific compliance requirements.

### QuickStart Variation
**File:** `deploy-arch-ibm-vsi-quickstart.md`

This variation has the following features to quickly start deployment:
- Pre-configured VSI settings
- Simple networking setup
- Basic storage configuration
- Minimal required inputs
- Fast deployment and teardown

**Best for:** Development and testing, proof-of-concept projects, learning environments, temporary workloads, simple applications.

## Architecture Diagrams

- `vsi-fully-configurable.svg` - Architecture diagram for the Fully configurable variation
- `vsi-quickstart.svg` - Architecture diagram for the QuickStart variation
- `heat-map-deploy-arch-vsi-fully-configurable.svg` - Design requirements diagram for Fully configurable
- `heat-map-deploy-arch-vsi-quickstart.svg` - Design requirements diagram for QuickStart
- `vsi.svg` - General VSI architecture diagram

## Related Documentation

- [Main module README](../README.md)
- [Solutions directory](../solutions/) - Contains the actual deployable architecture code
- [Examples directory](../examples/) - Contains usage examples
- [IBM Cloud VPC Documentation](https://cloud.ibm.com/docs/vpc)
