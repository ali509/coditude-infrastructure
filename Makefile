AWS_PROFILE ?= coditude-dev
AWS_REGION ?= ap-south-1
ROOT_TEMPLATE := infrastructure/root.yaml
NETWORK_TEMPLATE := infrastructure/nested/network.yaml
SECURITY_TEMPLATE := infrastructure/nested/security.yaml
DATABASE_TEMPLATE := infrastructure/nested/database.yaml
CONTAINER_FOUNDATION_TEMPLATE := infrastructure/nested/container-foundation.yaml
CONTAINER_APPLICATION_TEMPLATE := infrastructure/nested/container-application.yaml
EC2_PLATFORM_TEMPLATE := infrastructure/nested/ec2-platform.yaml
GUARD_RULES := infrastructure/policies/security.guard

.PHONY: infra-lint infra-guard root-lint network-validate security-validate database-validate container-foundation-validate container-application-validate ec2-platform-validate infra-validate

infra-lint:
	cfn-lint --format json --regions $(AWS_REGION) \
		--template $(ROOT_TEMPLATE) $(NETWORK_TEMPLATE) $(SECURITY_TEMPLATE) \
		$(DATABASE_TEMPLATE) $(CONTAINER_FOUNDATION_TEMPLATE) \
		$(CONTAINER_APPLICATION_TEMPLATE) $(EC2_PLATFORM_TEMPLATE)

root-lint:
	cfn-lint --regions $(AWS_REGION) --template $(ROOT_TEMPLATE)

infra-guard:
	cfn-guard validate \
		--rules $(GUARD_RULES) \
		--data $(ROOT_TEMPLATE) \
		--data infrastructure/nested \
		--type CFNTemplate \
		--show-summary all

network-validate:
	aws cloudformation validate-template \
		--template-body file://$(NETWORK_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

security-validate:
	aws cloudformation validate-template \
		--template-body file://$(SECURITY_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

database-validate:
	aws cloudformation validate-template \
		--template-body file://$(DATABASE_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

container-foundation-validate:
	aws cloudformation validate-template \
		--template-body file://$(CONTAINER_FOUNDATION_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

container-application-validate:
	aws cloudformation validate-template \
		--template-body file://$(CONTAINER_APPLICATION_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

ec2-platform-validate:
	aws cloudformation validate-template \
		--template-body file://$(EC2_PLATFORM_TEMPLATE) \
		--profile $(AWS_PROFILE) \
		--region $(AWS_REGION)

infra-validate: infra-lint network-validate security-validate database-validate container-foundation-validate container-application-validate ec2-platform-validate
