SHELL := /bin/bash

.PHONY: help deps deploy status logs shell destroy check

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

deps: ## Install required Ansible collections
	ansible-galaxy collection install -r requirements.yml

check: ## Syntax-check the playbooks
	ansible-playbook deploy.yml --syntax-check

deploy: ## Deploy (or reconcile) GitLab - fully idempotent (ARGS=... for extra flags)
	ansible-playbook deploy.yml $(ARGS)

status: ## Show GitLab pod/container status + the 30 GB filesystem usage
	@echo "--- pod ---"; podman pod ps --filter name=gitlab \
		--format 'table {{.Name}}\t{{.Status}}'
	@echo "--- container ---"; podman ps --filter name=gitlab \
		--format 'table {{.Names}}\t{{.Status}}'
	@echo "--- storage (hard cap) ---"; df -h /srv/gitlab-deployer || true

logs: ## Follow the GitLab container logs
	podman logs -f gitlab

shell: ## Drop into a shell inside the GitLab container
	podman exec -it gitlab bash

destroy: ## Remove the pod/container (KEEPS the data volume)
	ansible-playbook destroy.yml $(ARGS)
