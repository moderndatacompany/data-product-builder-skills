.PHONY: help network infra warehouse vulcan vulcan-shell vulcan-api vulcan-up setup all-down infra-down warehouse-down vulcan-down clean-volumes all-clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Setup targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(network|infra|warehouse|setup)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ''
	@echo 'Vulcan targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(vulcan|core|api)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ''
	@echo 'Cleanup targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '(down|clean)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

network: ## Create the external Docker network (Step 1)
	@echo "Creating external Docker network 'vulcan'..."
	@docker network create vulcan || echo "Network 'vulcan' already exists"

infra: network ## Start infrastructure services - statestore, minio (Step 2)
	@echo "Starting infrastructure services..."
	docker compose -f docker/docker-compose.infra.yml up -d

warehouse: network ## Start warehouse database (Step 3)
	@echo "Starting warehouse database..."
	docker compose -f docker/docker-compose.warehouse.yml up -d

setup: network infra warehouse ## Run all setup steps (network + infra + warehouse)
	@echo "Setup complete! Infrastructure and warehouse are running."
	@echo "You can now run 'make vulcan-shell' to start working with Vulcan."

vulcan-up: ## Start Vulcan API services - API and transpiler (Getting Started Step 3)
	@echo "Starting Vulcan API services..."
	docker compose -f docker/docker-compose.vulcan.yml up -d
	@echo "Vulcan API is available at http://localhost:8000/redoc"

vulcan-down: ## Stop Vulcan services
	@echo "Stopping Vulcan services..."
	docker compose -f docker/docker-compose.vulcan.yml down

infra-down: ## Stop infrastructure services
	@echo "Stopping infrastructure services..."
	docker compose -f docker/docker-compose.infra.yml down

warehouse-down: ## Stop warehouse services
	@echo "Stopping warehouse services..."
	docker compose -f docker/docker-compose.warehouse.yml down

all-down: vulcan-down infra-down warehouse-down ## Stop all services
	@echo "All services stopped."

all-clean: all-down ## Stop all services and remove all volumes
	@echo "Removing all Docker volumes..."
	@docker compose -f docker/docker-compose.infra.yml down -v || true
	@docker compose -f docker/docker-compose.warehouse.yml down -v || true
	@docker compose -f docker/docker-compose.vulcan.yml down -v || true
	@echo "All volumes removed."

