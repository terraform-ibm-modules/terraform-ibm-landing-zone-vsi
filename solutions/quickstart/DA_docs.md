# VSI Size Configuration

This document describes the compute size options and their configuration details. This table determines the virtual server instance specifications, including machine type, processing power, memory allocation, and storage configuration for the VSI deployment.

## VSI Size Table

| Size | Instance Profile | vCPU / Cores | GiB RAM | Bandwidth Cap (Gbps) | Instance Storage (GB) |  Notes
|--------------|------------------|--------------|---------|----------------------|-----------------------|-----------------------
| Mini         | bx2d-2x8         | 2 / 1        | 8       | 4                    | 1x75                  | General-purpose applications that need equal amounts of CPU and memory. Good starting point for most standard workloads.
| Small        | cx2d-2x4         | 2 / 1        | 4       | 4                    | 1x75                  | CPU-heavy tasks like web servers handling lots of visitors, data processing jobs, and applications that do heavy calculations.
| Medium       | mx2d-2x16        | 2 / 1        | 16      | 4                    | 1x75                  | Applications that need more memory, such as databases, analytics tools, and software that processes large amounts of data in memory.
| Large        | vx3d-2x32        | 2 / 1        | 32      | 4                    | 1x65                  | Memory-intensive applications like large databases, business intelligence tools (SAP), and applications that keep lots of data loaded in memory for fast access.
