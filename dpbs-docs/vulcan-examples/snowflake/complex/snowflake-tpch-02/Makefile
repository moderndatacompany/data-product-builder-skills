.PHONY: help network infra infra-down vulcan-up vulcan-down all-down all-clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

network: ## Create the external Docker network 'vulcan'
	@echo "Creating external Docker network 'vulcan'..."
	@docker network create vulcan || echo "Network 'vulcan' already exists"

infra: network ## Start infrastructure services (Postgres statestore + MinIO)
	@echo "Starting Snowflake TPC-H infra (statestore + minio)..."
	docker compose -f docker/docker-compose.infra.yml up -d

infra-down: ## Stop infrastructure services
	@echo "Stopping Snowflake TPC-H infra..."
	docker compose -f docker/docker-compose.infra.yml down

vulcan-up: ## Start Vulcan services (API + transpiler + graphql + mysql)
	@echo "Starting Vulcan services..."
	docker compose -f docker/docker-compose.vulcan.yml up -d

vulcan-down: ## Stop Vulcan services
	@echo "Stopping Vulcan services..."
	docker compose -f docker/docker-compose.vulcan.yml down

all-down: ## Stop Vulcan and infra services
	@$(MAKE) vulcan-down
	@$(MAKE) infra-down

all-clean: ## Stop infra and remove volumes
	@echo "Stopping infra and removing volumes..."
	@docker compose -f docker/docker-compose.infra.yml down -v || true
	@docker compose -f docker/docker-compose.vulcan.yml down -v || true


