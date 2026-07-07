.PHONY: help network infra-up infra-down vulcan-up vulcan-down up down clean vulcan info plan apply run test fmt lint logs

# Default target
help:
	@echo "SGWS Web Analytics - Snowflake + Vulcan"
	@echo ""
	@echo "Available targets:"
	@echo "  make network      - Create Docker network (one-time setup)"
	@echo "  make up           - Start all services (infra + vulcan)"
	@echo "  make down         - Stop all services"
	@echo "  make infra-up     - Start infrastructure only (statestore + minio)"
	@echo "  make infra-down   - Stop infrastructure"
	@echo "  make vulcan-up    - Start Vulcan services (API + transpiler)"
	@echo "  make vulcan-down  - Stop Vulcan services"
	@echo "  make logs         - View Vulcan API logs"
	@echo "  make clean        - Remove all volumes and networks"
	@echo ""
	@echo "Vulcan CLI commands (requires 'make vulcan' alias):"
	@echo "  make vulcan       - Setup Vulcan CLI alias"
	@echo "  make info         - Show project info"
	@echo "  make plan         - Preview changes"
	@echo "  make apply        - Create/update models"
	@echo "  make run          - Run data pipeline"
	@echo "  make test         - Run data quality tests"
	@echo "  make fmt          - Format SQL code"
	@echo "  make lint         - Lint SQL code"

# Create Docker network (one-time setup)
network:
	@echo "Creating Docker network 'vulcan'..."
	@docker network create vulcan || echo "Network already exists"

# Start infrastructure services
infra-up: network
	@echo "Starting infrastructure services (statestore + minio)..."
	@docker compose -f docker/docker-compose.infra.yml up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@docker compose -f docker/docker-compose.infra.yml ps

# Stop infrastructure services
infra-down:
	@echo "Stopping infrastructure services..."
	@docker compose -f docker/docker-compose.infra.yml down

# Start Vulcan services
vulcan-up: network
	@echo "Starting Vulcan services (API + transpiler)..."
	@VERSION=$${VERSION:-0.228.1} docker compose -f docker/docker-compose.vulcan.yml up -d
	@echo "Waiting for Vulcan API to be ready..."
	@sleep 5
	@docker compose -f docker/docker-compose.vulcan.yml ps

# Stop Vulcan services
vulcan-down:
	@echo "Stopping Vulcan services..."
	@docker compose -f docker/docker-compose.vulcan.yml down

# Start all services
up: infra-up vulcan-up
	@echo ""
	@echo "All services started!"
	@echo "Vulcan API: http://localhost:8000"
	@echo "MinIO Console: http://localhost:9001 (admin/password)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Setup Vulcan CLI: make vulcan"
	@echo "  2. Verify project: vulcan info"
	@echo "  3. Run pipeline: vulcan plan && vulcan apply && vulcan run"

# Stop all services
down: vulcan-down infra-down
	@echo "All services stopped"

# View Vulcan API logs
logs:
	@docker compose -f docker/docker-compose.vulcan.yml logs -f vulcan-api

# Clean everything (volumes + network)
clean: down
	@echo "Removing volumes..."
	@docker compose -f docker/docker-compose.infra.yml down -v
	@docker compose -f docker/docker-compose.vulcan.yml down -v
	@echo "Removing network..."
	@docker network rm vulcan || true
	@echo "Cleanup complete"

# Setup Vulcan CLI alias
vulcan:
	@echo "Setting up Vulcan CLI alias..."
	@echo ""
	@echo "Add this to your ~/.bashrc or ~/.zshrc:"
	@echo ""
	@echo "alias vulcan='docker run -it --network=vulcan --rm -v \"\$$PWD\":/workspace -w /workspace --env-file .env tmdcio/vulcan-snowflake:0.228.1 vulcan'"
	@echo ""
	@echo "Then run: source ~/.bashrc  # or source ~/.zshrc"
	@echo ""
	@echo "Or run this now:"
	@echo "alias vulcan='docker run -it --network=vulcan --rm -v \"\$$PWD\":/workspace -w /workspace --env-file .env tmdcio/vulcan-snowflake:0.228.1 vulcan'"

# Vulcan commands (require alias to be set)
info:
	@vulcan info

plan:
	@vulcan plan

apply:
	@vulcan apply

run:
	@vulcan run

test:
	@vulcan test

fmt:
	@vulcan fmt

lint:
	@vulcan lint

# Show status of all services
status:
	@echo "Infrastructure services:"
	@docker compose -f docker/docker-compose.infra.yml ps
	@echo ""
	@echo "Vulcan services:"
	@docker compose -f docker/docker-compose.vulcan.yml ps
