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
    ec2-platform.yaml
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
6. `ec2-platform.yaml` creates the non-containerized ALB, private frontend and
   backend Auto Scaling groups, CodeDeploy resources, Systems Manager access,
   CloudWatch logs, scaling policies, and basic alarms.

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
| `DeployEc2Platform` | `false` | Creates NAT, ALB, EC2, ASG and CodeDeploy |

Development and staging database stacks delete the database without retaining
a final snapshot. Production uses deletion protection and
`DeletionPolicy: Snapshot`.

The EC2 deployment path needs outbound access from its private subnets to
install and operate deployment agents. Enabling it selects one NAT Gateway,
including for development. Review the change set and expected charges before
executing this layer.

Frontend instances install the namespaced Amazon Linux Node.js 22 runtime and
receive a non-secret `BACKEND_URL` environment file that points to the
Application Load Balancer. Backend database credentials are not placed in
CloudFormation user data or CodeDeploy bundles. The backend reads the
RDS-managed secret at startup using its EC2 instance role.

## Basic Monitoring

Monitoring is embedded in the workload templates instead of being maintained
as a separate nested stack:

- ECS and EC2 application logs are retained in CloudWatch Logs.
- ALB target health checks identify unhealthy frontend and backend workloads.
- ECS services and EC2 Auto Scaling groups use CPU-based scaling.
- CloudWatch alarms cover unhealthy targets, sustained high ECS CPU, and ALB
  server errors.
- CodeDeploy stops and rolls back an EC2 release when its health alarms enter
  the alarm state.

This meets the assessment's monitoring requirement without adding a dashboard
or a separate monitoring stack.

## Local Validation

Run credential-free checks:

```bash
make infra-lint
make infra-guard
make root-lint
make ec2-platform-validate
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
