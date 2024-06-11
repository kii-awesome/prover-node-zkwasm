# Prover Node Docker

This is the docker container for the prover node. This container is responsible for running the prover node and handling tasks from the server.

## Table of Contents

- [Environment Setup](#environment)
  - [Setting up the Host Machine](#setting-up-the-host-machine)
- [Building](#building)
  - [Important](#important)
  - [Build the Docker Image](#build-the-docker-image)
- [Running](#running)
  - [Prover Node Configuration](#prover-node-configuration)
  - [Dry Run Service Configuration](#dry-run-service-configuration)
  - [HugePages Configuration](#hugepages-configuration)
  - [GPU Configuration](#gpu-configuration)
  - [Multiple Nodes on the same machine](#multiple-nodes-on-the-same-machine)

## Environment

The prover node requires a CUDA capable GPU, currently at minimum an RTX 4090.

The docker container is built on top of Nvidia's docker runtime and requires the Nvidia docker runtime to be installed on the host machine.

### Setting up the Host Machine

- Install NVIDIA Drivers for Ubuntu

  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#prerequisites

  https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html

  You can check if you have drivers installed with `nvidia-smi`

- Install Docker (From Nvidia, but feel free to install yourself!) https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#setting-up-docker

- Install Docker Compose
  https://docs.docker.com/compose/install/linux/#install-the-plugin-manually

- Install the Nvidia CUDA Toolkit + Nvidia docker runtime

We need to install the nvidia-container-toolkit on the host machine. This is a requirement for the docker container to be able to access the GPU.

https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#setting-up-nvidia-container-toolkit

Since the docs aren't the clearest, these are the commands to copy paste!

```
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```

and then

`sudo apt-get update`

and then

`sudo apt-get install -y nvidia-container-toolkit`

Configure Docker daemon to use the `nvidia` runtime as the default runtime.

`sudo nvidia-ctk runtime configure --runtime=docker --set-as-default`

Restart the docker daemon

`sudo systemctl restart docker` (Ubuntu)

`sudo service docker restart` (WSL Ubuntu)

Another method to set the runtime is to run this script after the cuda toolkit is installed.
https://github.com/NVIDIA/nvidia-docker

`sudo nvidia-ctk runtime configure`

## Building

The image is currently built with

- Ubuntu 22.04
- CUDA 12.2
- prover-node-release #be216b3fdb562a7e7d5982c6262768e6c977015c

**Important!**
The versions should not be changed unless the prover node is updated. The compiled prover node binary is sensitive to the CUDA version and the Ubuntu version.

### Build the Docker Image

Better clean the old docker image/volumes if you want.

To Build the docker image, run the following command in the root directory of the repository.

`bash build_image.sh`

We do not use BuildKit as there are issues with the CUDA runtime and BuildKit.

## Running

### Prover Node Configuration

**Important!**

This configuration file may change in the future. The prover node is currently in development and is subject to change. Ensure it is up to date with the latest version of the node.

The prover node requires a configuration file to be passed in at runtime.

- `server_url` - The URL of the server to connect to for tasks. The provided URL is the dockers reference to the host machines 'localhost'
- `priv_key` - The private key of the prover node. This is used to sign the tasks and prove the work was done by the prover node.

### Dry Run Service Configuration

The Dry Run service will be required to run parallel to the prover node. The Dry Run service is responsible for synchronising tasks with the server and ensuring the prover node is working correctly.
This service must be run in parallel to the prover node, so running the service through docker compose is recommended.

In the `dry_run_config.json` file, modify the connection strings to the server and the MongoDB instance.

- `server_url` - The URL of the server to connect to for tasks. Ensure this is the same as the prover node.
- `mongodb_uri` - The URI of the MongoDB instance to connect to.
- `priv_key` - Private Key is NOT used in the Dry Run service when run parallel to the prover node, so it can be ignored.

### HugePages Configuration

It is important to set the hugepages on the host machine to the correct value. This is done by setting the `vm.nr_hugepages` kernel parameter.

For a machine running a single prover node, the value should be set to ~15000. This is done with the following command.

`sysctl -w vm.nr_hugepages=15000`

### GPU Configuration

If you need to specify GPUs, you can do so in the `docker-compose.yml` file. The `device_ids` field is where you can specify the GPU's to use.

The starting command for the container will use `CUDA_VISIBLE_DEVICES=0` to specify the GPU to use.

You may also change the `device_ids` field in the `docker-compose.yml` file to specify the GPU's to use. Note that in the container the GPU indexing starts at 0.

Also ensure the `command` field in `docker-compose.yml` is modified for `CUDA_VISIBLE_DEVICES` to match the GPU you would like to use.

## MongoDB Configuration

MongoDB will work "out-of-the-box", however, if you need to do something specific, please refer the following section.

### Default Settings/Config

For most use cases, the default options should be sufficient.

The mongodb instance will run on port `27017` and the data will be stored in the `./mongo` directory.

Network mode is set to `host` to allow the prover node to connect to the mongodb instance via localhost, however if you prefer the port mapping method, you can change the port in the `docker-compose.yml` file.

If you are unsure about modifying or customizing changes, refer to the section below.

### Customising the MongoDB docker container

<details>
  <summary>View customization details</summary>
  
  #### The `mongo` docker image

For our `mongo` DB docker instance we are using the official docker image provided by `mongo` on their docker hub page, [here](https://hub.docker.com/_/mongo/), `mongo:latest`. They link to the `Dockerfile` they used to build the image, at the time of writing, [this](https://github.com/docker-library/mongo/blob/ea20b1f96f8a64f988bdcc03bb7cb234377c220c/7.0/Dockerfile) was the latest. It's important to have a glance at this if you want to customise our setup. The most essential thing to note is the **volumes,** which are `/data/db` and `/data/configdb`; any files you wish to mount should be mapped into these directories. Another critical piece of info is the **exposed port**, which is `27017`; this is the default port for `mongod`, if you want to change the port you have to bind it to another port in the `docker-compose.yml` file.

#### The `mongo` daemon config file

Even though we use a pre-build `mongo` image, this doesn't limit our customisability, because we are still able to pass command line arguments into the image via the `docker-compose` file. The most flexible way of customisation is by specifying a `mongod.conf` file and passing it to `mongod` via `--config` argument, this is what we have done to set the db path. The full list of customisation options are available [here.](https://www.mongodb.com/docs/manual/reference/configuration-options/)

#### The docker compose config file

##### DB Storage

Important to note is that our db storage is mounted locally under `./mongo` directory. The path is specified in the `mongod.conf` and the mount point is specified in `docker-compose.yml`. If you want to change the where the storage is located on the host machine, you only need to change the mount bind, for example to change the storage path to `/home/user/anotherdb`.

```yaml
services:
  mongodb:
    volumes:
      - /home/user/anotherdb:/data/db
```

##### DB Port

We don't set the **PORT** in the config file, rather, **the PORT is set in `docker-compose.yml`**; simply change the bindings, so your specific port is mapped to the port used by `mongo` image, e.g. changing port to `8099` is done like so:

```yaml
services:
  mongodb:
    ports:
      - "8099:27017"
```

If using host network mode, the port mapping will be ignored, and the port will be the default `27017`.
Specify the port by adding `--port <PORT>` to the `command` field in the `docker-compose.yml` file for the mongodb service.

##### Logging and log rotation

`mongo`'s logging feature is very basic and doesn't have the ability to clean up old logs, so instead we use dockers logging feature.

Docker logs all of standard output of a container into the folder `/var/lib/docker/containers/<container-id>/`.
Log rotation is enabled for both containers. Let's walk through the specified configuration parameters:

- `driver: "json-file"`: Specifies the logging driver. The json-file driver is the default and logs container output in JSON format.
- `max-size: "10m"`: Sets the maximum size of each log file to 10 megabytes. When this is exceeded the log is rotated.
- `max-file: "5"`: Specifies the maximum number of log files to keep. When the maximum number is reached, the oldest log file is deleted.
  More details can be found [here](https://docs.docker.com/config/containers/logging/configure/).

##### Network mode

Finally, we use `host` `network_mode`, this is because our server code refers to `mongo` DB via its local IP, i.e. localhost; if we want to switch to docker network mode then the code would need to be updated to use the public IP which would just be the host's public IP.

</details>

## Start

Make sure you had built the image via `bash build_image.sh`
Start all services at once with the following command, however it may clog up the terminal window as they all run in the same terminal so you may run some services in detached mode.

`docker compose up`

To start multiple containers on a machine, use the following command

`docker compose -p <node> up` where `node` is the unique name of the container/project you would like to start.

Ensure the docker compose file has GPU's specified for each container.

### Starting individual services

It may be cleaner to start services individually. You can start each in a new terminal window, or in the background.

To start each service in the background, use the following command

`docker compose start <service>`

To start an attached service, use the following command:

`docker compose up <service>`

It is required to start `mongodb` service first and then `prover-node` + `prover-dry-run-service` services.

### Multiple Nodes on the same machine

To run multiple prover nodes on the same machine, it is recommended to clone the repository and modify the required files.

- `docker-compose.yml`
- `prover-node-config.json`
- `dry_run_config.json`

There are a few things to consider when running multiple nodes on the same machine.

- GPU
- MongoDB instance
- Config file information
- Docker volume and container names

#### GPU

Ensure the GPU's are specified in the `docker-compose.yml` file for each node.
It is crucial that each GPU is only used ONCE otherwise you may encounter out of memory errors.
We recommend to set the `device_ids` field where you can specify the GPU to use in each `docker-compose.yml` file.

As mentioned, use `nvidia-smi` to check the GPU index and ensure the `device_ids` field is set correctly and uniquely.

#### MongoDB instance

Ensure the MongoDB instance is unique for each node. This is done by modifying the `docker-compose.yml` file for each node.

- Modify the `mongodb`services - `container_name` field to a unique value such as `zkwasm-mongodb-2` etc.
- Set the correct port to bind to the host machine. Please refer to the MongoDB configuration section for more information.
  - If using host network mode, the port is not required to be specified under services, but may be specified as part of the command field e.g `--port 8099`.

Ensure the `dry_run_config.json` file is updated with the correct MongoDB URI for each node.

#### Config file information

Ensure the `prover-config.json` file is updated with the correct server URL and private key for each node.

Private key should be UNIQUE for each node.

Ensure the `dry_run_config.json` file is updated with the correct server URL and MongoDB URI for each node.

#### Docker volume and container names

Ensure the docker volumes are unique for each node. This is done by modifying the `docker-compose.yml` file for each node.

The simplest method is to start the containers with a different project name from other directories/containers.

`docker compose -p <node> up -d`

Where `node` is the custom name of the services you would like to start i.e `node-2`. This is important to separate the containers and volumes from each other.

Follow the output of the container with `docker logs -f <node>_<service>` (Full name of container, which can be found with `docker ps` or `docker container ls`)
