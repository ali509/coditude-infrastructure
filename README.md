# Coditude Infrastructure

This repository contains the AWS infrastructure for the Coditude DevOps
assessment. It is owned by the DevOps or platform team and is intentionally
separate from the
[`coditude-application`](https://github.com/ali509/coditude-application)
repository.

Application developers change source code, tests, and Dockerfiles in the
application repository. Infrastructure changes, IAM, networking, security
controls, and deployment platform changes are reviewed here.

## Repository Layout

```text
infrastructure/
  root.yaml
  nested/
    network.yaml
    security.yaml
    database.yaml
    container-foundation.yaml
    container-application.yaml
    ec2-platform.yaml          # planned
    monitoring.yaml            # planned
    native-cicd.yaml           # planned
  policies/
    security.guard
```

`root.yaml` is the deployment entry point. It passes nested-stack outputs
directly into dependent stacks, keeping the complete environment under one
CloudFormation root stack.

## Current Architecture

1. `network.yaml` creates the VPC, three subnet tiers, routing, and optional
   cost-controlled network services.
2. `security.yaml` creates security groups for the load balancer, frontend,
   backend, database, and VPC endpoints.
3. `database.yaml` creates encrypted Amazon RDS for PostgreSQL with
   RDS-managed credentials in Secrets Manager.
4. `container-foundation.yaml` creates ECR repositories, ECS, log groups,
   service discovery, IAM, and optional private endpoints.
5. `container-application.yaml` creates the ALB, task definitions, Fargate
   services, health checks, private backend discovery, and service scaling.

The container platform is split into foundation and application stacks because
the ECR repositories must exist before the first immutable images can be
pushed.

## Cost-Safe Defaults

The root template deploys network and security by default. Billable layers
require explicit opt-in:

| Parameter | Default | Effect |
| --- | --- | --- |
| `DeployDatabase` | `false` | Creates RDS and its managed secret |
| `DeployContainerFoundation` | `false` | Creates ECS, ECR, logs and discovery |
| `EnablePrivateEndpoints` | `false` | Creates billable interface endpoints |
| `DeployContainerApplication` | `false` | Creates ALB and Fargate services |

Development and staging database stacks delete the database without retaining
a final snapshot. Production uses deletion protection and
`DeletionPolicy: Snapshot`.

## Local Validation

Run credential-free checks:

```bash
make infra-lint
make infra-guard
make root-lint
```

Run AWS-side template validation with the configured profile:

```bash
make infra-validate AWS_PROFILE=coditude-dev AWS_REGION=ap-south-1
```

These commands validate templates but do not create resources.

## Packaging And Change Sets

Nested templates must be uploaded to S3 before the root stack can be deployed:

```bash
aws cloudformation package \
  --template-file infrastructure/root.yaml \
  --s3-bucket YOUR_ARTIFACT_BUCKET \
  --output-template-file infrastructure/packaged-root.yaml \
  --profile coditude-dev \
  --region ap-south-1
```

Create and inspect a CloudFormation change set before execution. Staging and
production execution will require approval through GitHub Environments.

## Application Contract

The infrastructure stack supplies environment-specific values to the
application deployment workflow:

- AWS Region and GitHub OIDC deployment role
- ECS cluster name
- Frontend and backend ECS service names
- Frontend and backend ECR repository URIs

The application repository builds and publishes immutable images. It does not
run CloudFormation. This repository provisions and changes the platform. It
does not build application source.

## Multi-Environment Strategy

One reusable template set supports `dev`, `staging`, and `prod`. The
`Environment` parameter, mappings, and conditions select capacity, retention,
availability, and protection settings. Each deployed environment has its own
CloudFormation stack and resources, while the templates remain identical.

Use short-lived feature branches and pull requests into a protected `main`
branch. GitHub Environments provide environment-specific variables, deployment
approvals, and production protection.
