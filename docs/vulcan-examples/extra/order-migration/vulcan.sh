#!/bin/bash
# Vulcan CLI wrapper for postgres example
# Usage: ./vulcan.sh <command> [args...]
#
# Examples:
#   ./vulcan.sh run
#   ./vulcan.sh test
#   ./vulcan.sh transpiler up
#   ./vulcan.sh transpile --format sql "select measure(x) from table"
#   ./vulcan.sh api

set -e

VERSION="${VERSION:-0.228.1}"
NETWORK="vulcan"
IMAGE="tmdcio/vulcan-postgres:${VERSION}"

# Service URLs within Docker network
# Note: Docker Compose prefixes container names with project name (directory name = "docker")
VULCAN_API_URL="http://docker-vulcan-api-1:8000"
VULCAN_TRANSPILER_URL="http://docker-vulcan-transpiler-1:4000"

# Ensure network exists
docker network create ${NETWORK} 2>/dev/null || true

# Commands that need docker-compose (can't run inside container)
COMPOSE_COMMANDS=("transpiler" "infra" "warehouse")

# Check if command needs docker-compose
needs_compose() {
    local cmd="$1"
    for dc in "${COMPOSE_COMMANDS[@]}"; do
        if [[ "$cmd" == "$dc" ]]; then
            return 0
        fi
    done
    return 1
}

if [[ $# -eq 0 ]]; then
    echo "Usage: ./vulcan.sh <command> [args...]"
    echo ""
    echo "Examples:"
    echo "  ./vulcan.sh run                    # Run all models"
    echo "  ./vulcan.sh test                   # Run tests"
    echo "  ./vulcan.sh check                  # Run checks"
    echo "  ./vulcan.sh transpiler up          # Start transpiler service"
    echo "  ./vulcan.sh transpiler down        # Stop transpiler service"
    echo "  ./vulcan.sh transpile --format sql 'select measure(x) from t'"
    echo "  ./vulcan.sh api                    # Start API server"
    echo ""
    echo "Infrastructure:"
    echo "  ./vulcan.sh infra up               # Start PostgreSQL, MinIO, etc."
    echo "  ./vulcan.sh warehouse up           # Start warehouse"
    echo "  ./vulcan.sh all up                 # Start everything"
    echo "  ./vulcan.sh all down               # Stop everything"
    exit 1
fi

CMD="$1"
shift

# Handle 'all' command
if [[ "$CMD" == "all" ]]; then
    if [[ "$1" == "up" ]]; then
        echo "Starting all services..."
        docker compose -f docker/docker-compose.infra.yml up -d
        docker compose -f docker/docker-compose.warehouse.yml up -d
        docker compose -f docker/docker-compose.vulcan.yml up -d
        echo "✓ All services started. Check with: docker ps"
    elif [[ "$1" == "down" ]]; then
        echo "Stopping all services..."
        docker compose -f docker/docker-compose.vulcan.yml down
        docker compose -f docker/docker-compose.warehouse.yml down
        docker compose -f docker/docker-compose.infra.yml down
        echo "✓ All services stopped."
    fi
    exit 0
fi

if needs_compose "$CMD"; then
    # For transpiler/infra commands, use docker-compose directly
    case "$CMD" in
        "transpiler")
            if [[ "$1" == "up" ]]; then
                echo "Starting transpiler via docker-compose..."
                docker compose -f docker/docker-compose.vulcan.yml up -d vulcan-transpiler vulcan-api
                echo "✓ Transpiler started. Check with: docker ps"
                echo ""
                echo "Now you can run:"
                echo "  ./vulcan.sh transpile --format sql \"select measure(active_customers) from customers\""
            elif [[ "$1" == "down" ]]; then
                docker compose -f docker/docker-compose.vulcan.yml down
            else
                docker compose -f docker/docker-compose.vulcan.yml "$@"
            fi
            ;;
        "infra")
            if [[ "$1" == "up" ]]; then
                echo "Starting infrastructure..."
                docker compose -f docker/docker-compose.infra.yml up -d
                echo "✓ Infrastructure started."
            elif [[ "$1" == "down" ]]; then
                docker compose -f docker/docker-compose.infra.yml down
            else
                docker compose -f docker/docker-compose.infra.yml "$@"
            fi
            ;;
        "warehouse")
            if [[ "$1" == "up" ]]; then
                echo "Starting warehouse..."
                docker compose -f docker/docker-compose.warehouse.yml up -d
                echo "✓ Warehouse started."
            elif [[ "$1" == "down" ]]; then
                docker compose -f docker/docker-compose.warehouse.yml down
            else
                docker compose -f docker/docker-compose.warehouse.yml "$@"
            fi
            ;;
    esac
else
    # For other commands, run vulcan directly in container
    # Pass transpiler URL so it can connect to the service
    # Use TTY only when running interactively (CI/non-TTY should not use -it)
    DOCKER_TTY_ARGS=""
    if [ -t 0 ] && [ -t 1 ]; then
        DOCKER_TTY_ARGS="-it"
    fi

    docker run ${DOCKER_TTY_ARGS} --rm \
        --network=${NETWORK} \
        -v "$(pwd)":/workspace \
        -e VULCAN_API_URL=${VULCAN_API_URL} \
        -e VULCAN_TRANSPILER_URL=${VULCAN_TRANSPILER_URL} \
        ${IMAGE} \
        vulcan "$CMD" "$@"
fi
