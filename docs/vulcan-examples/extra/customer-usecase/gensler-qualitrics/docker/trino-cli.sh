#!/bin/bash
# Trino CLI Helper Script
# This script provides easy access to the Trino CLI

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Connecting to Trino...${NC}"

# Check if Trino container is running
if ! docker ps | grep -q trino; then
    echo -e "${GREEN}Trino container is not running. Starting services...${NC}"
    docker-compose -f docker-compose.infra.yml up -d trino
    echo -e "${GREEN}Waiting for Trino to be ready...${NC}"
    sleep 10
fi

# Execute Trino CLI
docker exec -it trino trino "$@"

