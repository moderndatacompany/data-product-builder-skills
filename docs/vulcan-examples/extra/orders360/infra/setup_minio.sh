#!/bin/bash
# Setup MinIO bucket for query results

set -e

echo "🪣 Setting up MinIO bucket: warehouse"

# Wait for MinIO to be ready
echo "⏳ Waiting for MinIO to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

until docker exec databricks_minio mc alias set local http://localhost:9000 admin password 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ MinIO failed to become ready after ${MAX_RETRIES} attempts"
    echo "   Make sure MinIO is running: cd infra && docker-compose up -d minio"
    exit 1
  fi
  echo "   Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep 2
done

echo "✅ MinIO is ready"

# Create bucket (ignore if exists)
echo "📦 Creating bucket: warehouse"
docker exec databricks_minio \
  mc mb local/warehouse --ignore-existing

# Set download policy for queries prefix
echo "🔓 Setting download policy for queries/ prefix"
docker exec databricks_minio \
  mc anonymous set download local/warehouse/queries

echo ""
echo "=" * 80
echo "✅ MinIO Setup Complete!"
echo "=" * 80
echo ""
echo "Bucket: warehouse"
echo "Base path: queries/"
echo "Console: http://localhost:9001 (admin/password)"
echo ""
echo "Test with:"
echo "  cd ../.."
echo "  source .env/bin/activate"
echo "  python test_object_store.py"
echo ""

