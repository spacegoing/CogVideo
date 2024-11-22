#!/bin/bash

# File containing prompts
PROMPTS_FILE="/workspace/Open-Sora-Plan/myprompts/easy.txt"

# Output directory
OUTPUT_DIR="./out"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Counter to track the order of prompts
order=1

# Loop through each line in the file
while IFS= read -r prompt || [[ -n "$prompt" ]]; do
    # Construct the output file path
    output_path="$OUTPUT_DIR/$order.mp4"

    # Run the Python script with the prompt and output path
    python my_cli_demo.py --prompt "$prompt" --output_path "$output_path"

    # Increment the order counter
    order=$((order + 1))
done < "$PROMPTS_FILE"
