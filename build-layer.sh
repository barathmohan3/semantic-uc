#!/bin/bash

set -e

echo "🛠️ Building Lambda Layer with dependencies..."

# Create build folder
mkdir -p lambda/layer/python

# Install deps into the layer
pip install --platform manylinux2014_x86_64 \
            --target=lambda/layer/python \
            --implementation cp \
            --python-version 3.9 \
            --only-binary=:all: \
            --upgrade \
            psycopg2-binary openai boto3 PyPDF2

# Zip it
cd lambda/layer
zip -r ../../layer.zip python > /dev/null
cd ../../

echo "✅ Done. layer.zip is ready to upload."
