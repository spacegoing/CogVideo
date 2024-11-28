#!/bin/bash

# File containing image paths and prompts in the format [img_path]:::[prompt]
INPUT_FILE="/workspace/CogVideo/myprompts/Human/i2v_inputs.txt"
MODEL_PATH="/workspace/public/models/CogVideoX1.5-5B-I2V"

# Output directory
OUTPUT_DIR="./out"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Number of GPUs available
NUM_GPUS=8

# Counter to track the order of prompts
order=1

# Declare an associative array to track GPU PIDs
declare -A gpu_pids

# Initialize all GPUs as "available" (PID=0)
for ((gpu_id=0; gpu_id<NUM_GPUS; gpu_id++)); do
    gpu_pids[$gpu_id]=0
done

# Function to check if a GPU is available
is_gpu_available() {
    local gpu_id=$1
    local pid=${gpu_pids[$gpu_id]}
    if [[ $pid -eq 0 ]]; then
        return 0  # GPU is available
    else
        if kill -0 $pid 2>/dev/null; then
            return 1  # Process is still running, GPU is busy
        else
            gpu_pids[$gpu_id]=0  # Process has completed, free GPU
            return 0  # GPU is now available
        fi
    fi
}

# Function to process a single prompt pair on a specific GPU
process_prompt() {
    local gpu_id=$1
    local img_path=$2
    local prompt=$3
    local output_path=$4

    echo "GPU ID: $gpu_id"
    echo "Prompt: $prompt"

    # Run the Python script on the specified GPU
    CUDA_VISIBLE_DEVICES="$gpu_id" python my_cli_demo.py --prompt "$prompt" --output_path "$output_path" \
                        --model_path "$MODEL_PATH" \
                        --image_or_video_path "$img_path" \
                        --lora_path "/workspace/CogVideo/finetune/cogvideox-lora-single-node/pytorch_lora_weights.safetensors" \
                        --generate_type "i2v"
}

# Loop through each line in the input file
while IFS= read -r line || [[ -n "$line" ]]; do
    # Extract the image path and prompt using the delimiter `:::`
    img_path=$(echo "$line" | awk -F ':::' '{print $1}')
    prompt=$(echo "$line" | awk -F ':::' '{print $2}')

    # Construct the output file path
    output_path="$OUTPUT_DIR/$order.mp4"

    while :; do
        # Find the first available GPU
        for ((gpu_id=0; gpu_id<NUM_GPUS; gpu_id++)); do
            if is_gpu_available "$gpu_id"; then
                # Found an available GPU, assign the job
                process_prompt "$gpu_id" "$img_path" "$prompt" "$output_path" &
                pid=$!
                gpu_pids[$gpu_id]=$pid
                break 2
            fi
        done

        # If no GPU is available, wait briefly before checking again
        sleep 1
    done

    # Increment the order counter
    order=$((order + 1))
done < "$INPUT_FILE"

# Wait for all remaining background processes to complete
wait
