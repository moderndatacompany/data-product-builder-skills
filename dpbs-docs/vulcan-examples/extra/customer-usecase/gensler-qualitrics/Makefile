.PHONY: help nilus nilus-server nilus-compose infra spark vulcan \
        nilus-down nilus-server-down nilus-compose-down \
        infra-down spark-down vulcan-down all-down all-clean \
        network-create network-remove logs

# Color codes for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Paths
DOCKER_DIR := docker
NILUS_DIR := nilus/local-working

# Default target - show help
help:
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         Docker Compose Management Makefile                ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Nilus Commands:$(NC)"
	@echo "  $(YELLOW)make nilus$(NC)              - Start Nilus infrastructure (docker-compose.yaml)"
	@echo "  $(YELLOW)make nilus-server$(NC)       - Start Nilus server (nilus-server.yaml) in detached mode"
	@echo "  $(YELLOW)make nilus-compose$(NC)      - Start Nilus batch (nilus-compose.yaml)"
	@echo "  $(YELLOW)make nilus-down$(NC)         - Stop Nilus infrastructure"
	@echo "  $(YELLOW)make nilus-server-down$(NC)  - Stop Nilus server"
	@echo "  $(YELLOW)make nilus-compose-down$(NC) - Stop Nilus batch"
	@echo ""
	@echo "$(GREEN)Vulcan Commands:$(NC)"
	@echo "  $(YELLOW)make infra$(NC)              - Start Vulcan infrastructure (docker-compose.infra.yml)"
	@echo "  $(YELLOW)make spark$(NC)              - Start Spark cluster (docker-compose.spark.yml)"
	@echo "  $(YELLOW)make vulcan$(NC)             - Start Vulcan services (docker-compose.vulcan.yml)"
	@echo "  $(YELLOW)make infra-down$(NC)         - Stop Vulcan infrastructure"
	@echo "  $(YELLOW)make spark-down$(NC)         - Stop Spark cluster"
	@echo "  $(YELLOW)make vulcan-down$(NC)        - Stop Vulcan services"
	@echo ""
	@echo "$(GREEN)Combined Commands:$(NC)"
	@echo "  $(YELLOW)make all-down$(NC)           - Stop all containers (Nilus + Vulcan)"
	@echo "  $(YELLOW)make all-clean$(NC)          - Stop and remove all containers, networks, and volumes"
	@echo ""
	@echo "$(GREEN)Utility Commands:$(NC)"
	@echo "  $(YELLOW)make network-create$(NC)     - Create the vulcan network"
	@echo "  $(YELLOW)make logs-nilus$(NC)         - View Nilus logs"
	@echo "  $(YELLOW)make logs-vulcan$(NC)        - View Vulcan logs"
	@echo "  $(YELLOW)make status$(NC)             - Show status of all containers"
	@echo ""

# ==========================================
# Network Management
# ==========================================
network-create:
	@echo "$(GREEN)Creating vulcan network...$(NC)"
	@docker network create vulcan 2>/dev/null || echo "$(YELLOW)Network 'vulcan' already exists$(NC)"

# ==========================================
# Nilus Commands
# ==========================================
nilus: network-create
	@echo "$(GREEN)Starting Nilus infrastructure...$(NC)"
	cd $(NILUS_DIR) && docker compose -f docker-compose.yaml up

nilus-server: network-create
	@echo "$(GREEN)Starting Nilus server (detached mode)...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-server.yaml up -d
	@echo "$(GREEN)✓ Nilus server started in detached mode$(NC)"

nilus-compose: network-create
	@echo "$(GREEN)Starting Nilus batch processing...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-compose.yaml up

nilus-down:
	@echo "$(YELLOW)Stopping Nilus infrastructure...$(NC)"
	cd $(NILUS_DIR) && docker compose -f docker-compose.yaml down

nilus-server-down:
	@echo "$(YELLOW)Stopping Nilus server...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-server.yaml down

nilus-compose-down:
	@echo "$(YELLOW)Stopping Nilus batch processing...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-compose.yaml down

# ==========================================
# Vulcan Commands
# ==========================================
infra: network-create
	@echo "$(GREEN)Starting Vulcan infrastructure...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.infra.yml up -d
	@echo "$(GREEN)✓ Vulcan infrastructure started$(NC)"

spark: network-create
	@echo "$(GREEN)Starting Spark cluster...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.spark.yml up -d
	@echo "$(GREEN)✓ Spark cluster started$(NC)"

vulcan: network-create
	@echo "$(GREEN)Starting Vulcan services...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.vulcan.yml up -d
	@echo "$(GREEN)✓ Vulcan services started$(NC)"

infra-down:
	@echo "$(YELLOW)Stopping Vulcan infrastructure...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.infra.yml down

spark-down:
	@echo "$(YELLOW)Stopping Spark cluster...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.spark.yml down

vulcan-down:
	@echo "$(YELLOW)Stopping Vulcan services...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.vulcan.yml down

# ==========================================
# Combined Operations
# ==========================================
all-down:
	@echo "$(RED)Stopping all containers...$(NC)"
	@echo "$(YELLOW)Stopping Nilus services...$(NC)"
	-cd $(NILUS_DIR) && docker compose -f docker-compose.yaml down 2>/dev/null
	-cd $(NILUS_DIR) && docker compose -f nilus-server.yaml down 2>/dev/null
	-cd $(NILUS_DIR) && docker compose -f nilus-compose.yaml down 2>/dev/null
	@echo "$(YELLOW)Stopping Vulcan services...$(NC)"
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.vulcan.yml down 2>/dev/null
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.spark.yml down 2>/dev/null
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.infra.yml down 2>/dev/null
	@echo "$(GREEN)✓ All containers stopped$(NC)"

all-clean:
	@echo "$(RED)Cleaning up all containers, networks, and volumes...$(NC)"
	@echo "$(YELLOW)Cleaning Nilus services...$(NC)"
	-cd $(NILUS_DIR) && docker compose -f docker-compose.yaml down -v --remove-orphans 2>/dev/null
	-cd $(NILUS_DIR) && docker compose -f nilus-server.yaml down -v --remove-orphans 2>/dev/null
	-cd $(NILUS_DIR) && docker compose -f nilus-compose.yaml down -v --remove-orphans 2>/dev/null
	@echo "$(YELLOW)Cleaning Vulcan services...$(NC)"
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.vulcan.yml down -v --remove-orphans 2>/dev/null
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.spark.yml down -v --remove-orphans 2>/dev/null
	-cd $(DOCKER_DIR) && docker compose -f docker-compose.infra.yml down -v --remove-orphans 2>/dev/null
	@echo "$(YELLOW)Removing network...$(NC)"
	-docker network rm vulcan 2>/dev/null || true
	@echo "$(GREEN)✓ All containers, volumes, and networks cleaned$(NC)"

# ==========================================
# Logging & Monitoring
# ==========================================
logs-nilus:
	@echo "$(BLUE)Viewing Nilus logs (Ctrl+C to exit)...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-server.yaml logs -f

logs-nilus-batch:
	@echo "$(BLUE)Viewing Nilus batch logs (Ctrl+C to exit)...$(NC)"
	cd $(NILUS_DIR) && docker compose -f nilus-compose.yaml logs -f

logs-vulcan:
	@echo "$(BLUE)Viewing Vulcan logs (Ctrl+C to exit)...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.vulcan.yml logs -f

logs-spark:
	@echo "$(BLUE)Viewing Spark logs (Ctrl+C to exit)...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.spark.yml logs -f

logs-infra:
	@echo "$(BLUE)Viewing Infrastructure logs (Ctrl+C to exit)...$(NC)"
	cd $(DOCKER_DIR) && docker compose -f docker-compose.infra.yml logs -f

status:
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║              Container Status                              ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@docker ps -a --filter "name=nilus" --filter "name=spark" --filter "name=vulcan" --filter "name=statestore" --filter "name=warehouse" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ==========================================
# Quick Start Commands
# ==========================================
start-vulcan-all: network-create infra spark vulcan
	@echo "$(GREEN)✓ All Vulcan services started!$(NC)"
	@echo "$(BLUE)Access points:$(NC)"
	@echo "  - Vulcan API: http://localhost:8100"
	@echo "  - Vulcan Transpiler: http://localhost:4000"
	@echo "  - Spark Master UI: http://localhost:8081"
	@echo "  - PostgreSQL Statestore: localhost:5431"
	@echo "  - PostgreSQL Warehouse: localhost:5433"

start-nilus-all: network-create nilus-server
	@echo "$(GREEN)✓ Nilus server started!$(NC)"
	@echo "$(BLUE)Access points:$(NC)"
	@echo "  - Nilus API: http://localhost:8000"
	@echo "  - Prometheus: http://localhost:9090"
	@echo "  - Pushgateway: http://localhost:9091"

# ==========================================
# Restart Commands
# ==========================================
restart-nilus-server: nilus-server-down nilus-server
	@echo "$(GREEN)✓ Nilus server restarted$(NC)"

restart-vulcan: vulcan-down vulcan
	@echo "$(GREEN)✓ Vulcan services restarted$(NC)"

restart-spark: spark-down spark
	@echo "$(GREEN)✓ Spark cluster restarted$(NC)"

