# This script will perform some basic actions for when the prover node is upgraded.
# Manually run this script to clear the workspace and rebuild the docker image.

# This script also assumes the prover node has been started using defaults.
# If you used docker compose -p <project_name> up, then please modify the script to use the correct project name.

# Prune unused docker containers
docker container prune -f

# Prune unused docker volumes
docker volume prune -f

# Remove the workspace volume
docker volume rm prover-node-docker_workspace-volume

# Remove the image and re-pull the latest image
docker image rm zkwasm:latest

# Rebuild image locally
DOCKER_BUILDKIT=0 docker build --rm --network=host -t zkwasm .