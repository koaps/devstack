# Use the latest Ubuntu image
FROM ollama/ollama:latest

# Get build argument model passed to docker compose.
ARG OLLAMA_MODEL
# Get environmental variable model.
ENV OLLAMA_MODEL=$OLLAMA_MODEL

# Start Ollama serve in background.
# Sleep in order to let it start.
# Pull selected Ollama model.
# Run the selected Ollama model.
RUN ollama serve & \
    sleep 10 && \
    ollama pull "$OLLAMA_MODEL" && \
    ollama run "$OLLAMA_MODEL"
