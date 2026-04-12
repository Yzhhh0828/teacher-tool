#!/bin/bash
set -e

echo "Running database migrations..."

cd /app

# Install alembic if needed
pip install alembic

# Run migrations
alembic upgrade head

echo "Migrations completed"
