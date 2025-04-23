             @@@@@                                                                
       @@@@@@@@@@@@@@@@@                                                          
    @@@@@@@@@@@@@@@   @@@@@                                                       
  @@@@@@@@@@@@@@ @@@@@@  @@@@                                                     
 @@@@@@@@@@@@@@@@@@  @@@@  @@@   .d88b.       w             888b.            8    
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   8P  Y8 8d8b. w .d8b. 8d8b. 8   8 .d8b. .d8b 8.dP 
@@@@@@@@@@@@@@@@   @@  @@@  @@@  8b  d8 8P Y8 8 8' .8 8P Y8 8   8 8' .8 8    88b  
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   \`Y88P' 8   8 8 \`Y8P' 8   8 888P' \`Y8P' \`Y8P 8 Yb 
 @@@@@@@@@@@@@@@@@@  @@@@ @@@@   ~- By TN3W: https://github.com/tn3w/OnionDock -~ 
  @@@@@@@@@@@@@@@@@@@@@  @@@                                                      
    @@@@@@@@@@@@@@@   @@@@@                                                       
       @@@@@@@@@@@@@@@@@                                                          
```

**OnionDock** is a turnkey solution for deploying web applications as Tor hidden services with enhanced security, reliability, and performance.


## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
  - [Docker Hub Images](#docker-hub-images)
- [Usage](#usage)
  - [Deploy Your Own Application](#deploy-your-own-application)
  - [Configure Hidden Service Ports](#configure-hidden-service-ports)
  - [Add a Load Balancer](#add-a-load-balancer)
  - [Add a Database Service](#add-a-database-service)
- [Configuration](#configuration)
  - [Security Levels](#security-levels)
  - [Advanced Tor Configuration](#advanced-tor-configuration)
- [Building from Source](#building-from-source)
  - [Installing Prerequisites](#installing-prerequisites)
  - [Building Standard Image](#building-standard-image)
  - [Building Tor from Source](#building-tor-from-source)
- [Development](#development)
  - [Code Formatting](#code-formatting)
  - [Project Structure](#project-structure)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Overview

OnionDock provides a pre-configured Docker environment with a hardened Tor instance that includes security enhancements from the official [Vanguards](https://github.com/mikeperry-tor/vanguards) project. It enables developers to quickly deploy their web applications on the Tor network with minimal configuration while maintaining strong security practices.

## Features

- **Secure Tor Configuration**: 
  - Hardened Tor instance with security best practices
  - Automatically rotates guard nodes to prevent long-term correlation attacks
  - Includes protection against many common Tor attacks

- **Official Security Enhancements**:
  - **Vanguards**: Protection against guard discovery attacks
  - **BandGuard**: Mitigation of bandwidth side-channel attacks
  - **RendGuard**: Protection against rendezvous point enumeration attacks
  - **CbtVerify**: Detection of circuit build time anomalies
  - **DropTimeouts**: Dropping circuits that timeout in certain states

- **Performance Optimized**: 
  - Automatic multi-threading for improved Tor performance
  - Parallel execution of Vanguards components for better CPU utilization
  - Dockerized environment for consistent resource allocation

- **Easy Integration**: 
  - Simple port sharing between your web application and the Tor hidden service
  - Compatible with any containerized web application
  - Plug-and-play with existing Docker Compose setups

- **Modular Design**: 
  - Easily add your own web applications, load balancers, Redis, or other services
  - Supports complex multi-container architectures
  - Extensible for various deployment scenarios

- **Docker-based**: 
  - Containerized for consistent deployment across environments
  - Version-controlled dependencies
  - Simplified setup and teardown

## Architecture

OnionDock consists of the following components:

- **Tor Service**: A hardened Tor instance with enhanced security modules
- **Vanguards Addon**: 
  - Official security implementation from the [Vanguards](https://github.com/mikeperry-tor/vanguards) project
  - Components (Vanguards, BandGuards, RendGuards) run in parallel processes for better performance
- **Network Bridge**: Connects your application containers to the Tor service
- **Volume Mounts**: For persistence of Tor keys and configurations

**Simplified Architecture Diagram:**

```
+----------------------------------+
|          Docker Network          |
|                                  |
|  +------------+    +----------+  |
|  |            |    |          |  |
|  |     Tor    |--->|  Your    |  |
|  |  Service   |    |   App    |  |
|  |            |<---|          |  |
|  +------------+    +----------+  |
|       ^                          |
|       |                          |
+-------|--------------------------|
        |                          
        v                          
   Internet via                    
   Tor Network                     
```

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your system
- Basic understanding of Docker containers and networks

### Docker Hub Images

OnionDock is available as pre-built Docker images on Docker Hub. This is the recommended way to use OnionDock.

**Standard Image** (with packaged Tor):
```bash
docker pull tn3w/oniondock:latest
```

**From-Source Image** (with Tor built from source for enhanced security):
```bash
docker pull tn3w/oniondock:from-source
```

### Quick Start

Follow these steps to deploy the example application using the Docker Hub image:

1. **Clone this repository**:
   ```bash
   git clone https://github.com/tn3w/OnionDock.git
   cd OnionDock/example
   ```

2. **Create a docker-compose.yml file**:
   ```yaml
   services:
     tor:
       image: tn3w/oniondock:latest
       volumes:
         - ./data/tor/hidden_service:/var/lib/tor/hidden_service:rw
       restart: unless-stopped
       networks:
         - onion_network
       depends_on:
         - webapp
   
     webapp:
       build:
         context: ./app
       networks:
         - onion_network
       restart: unless-stopped
   
   networks:
     onion_network:
       driver: bridge
   ```

3. **Build and start the services**:
   ```bash
   docker compose up -d
   ```

4. **Get your Tor hidden service address**:
   ```bash
   docker compose logs tor | grep "Tor hidden service"
   ```

   You should see output similar to:
   ```
   [+] Tor hidden service at: abcdefghijklmnopqrstuvwxyz234567.onion
   ```

5. **Access your hidden service**:
   
   Open the Tor Browser and navigate to the onion address shown in the previous step.

**All-in-one command**:
```bash
git clone https://github.com/tn3w/OnionDock.git && \
cd OnionDock/example && \
docker compose up -d && \
sleep 10 && \
docker compose logs tor | grep "Tor hidden service"
```

### Cleaning Up

To stop and remove all containers:

```bash
docker compose down
```

## Usage

### Deploy Your Own Application

To deploy your own application with OnionDock, follow these steps:

1. **Create a project structure**:
   ```
   your-project/
   ├── app/
   │   ├── Dockerfile
   │   └── your-application-files
   ├── data/
   │   └── tor/
   │       └── hidden_service/  # This will be created automatically
   └── docker-compose.yml
   ```

2. **Create your docker-compose.yml**:
   ```yaml
   services:
     tor:
       image: tn3w/oniondock:latest  # Use the Docker Hub image
       volumes:
         - ./data/tor/hidden_service:/var/lib/tor/hidden_service:rw
       restart: unless-stopped
       networks:
         - onion_network
       depends_on:
         - your-app-service
   
     your-app-service:
       build:
         context: ./app
       # If your app listens on port 3000 internally:
       environment:
         - PORT=3000  # The port your application listens on
       networks:
         - onion_network
       restart: unless-stopped
   
   networks:
     onion_network:
       driver: bridge
   ```

3. **Configure the Tor service**:
   
   Create a custom torrc configuration to map your service's port:

   ```
   # Create this file at tor/config/torrc
   HiddenServiceDir /var/lib/tor/hidden_service
   HiddenServiceVersion 3
   HiddenServicePort 80 your-app-service:3000  # Map port 80 on .onion to your app's port 3000
   ```

4. **Start your services**:
   ```bash
   docker compose up -d
   ```

5. **Get your Tor hidden service address**:
   ```bash
   docker compose logs tor | grep "Tor hidden service"
   ```

## Configuration

### Security Levels

OnionDock can be customized through environment variables:

- `SECURITY_LEVEL`: Level of security guards (default: high)
  - `high`: All security components enabled, running in parallel
  - `medium`: Basic security components without circuit build time verification
  - `low`: Minimal security with only vanguards layer protection

Example docker-compose.yml with security configuration:
```yaml
services:
  tor:
    image: oniondock:latest
    environment:
      - SECURITY_LEVEL=high  # Options: high, medium, low
    # ...other configuration
```

### Advanced Tor Configuration

You can mount a custom torrc file to configure Tor settings:

```yaml
services:
  tor:
    image: oniondock:latest
    volumes:
      - ./data/tor/hidden_service:/var/lib/tor/hidden_service:rw
      - ./tor/custom-torrc:/etc/tor/torrc:ro
    # ...other configuration
```

Example advanced torrc settings:

```
# Core Tor configuration
DataDirectory /var/lib/tor
ControlPort 9051
CookieAuthentication 1

# Hidden service configuration
HiddenServiceDir /var/lib/tor/hidden_service
HiddenServiceVersion 3
HiddenServicePort 80 webapp:3000

# Security enhancements
StrictNodes 1
EnforceDistinctSubnets 1
WarnUnsafeSocks 1
```

## Building from Source

If you prefer to build the OnionDock images locally rather than using the pre-built Docker Hub images, follow these instructions.

### Installing Prerequisites

#### Installing Prerequisites on Ubuntu/Debian

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install Git
sudo apt install -y git

# Install Docker prerequisites
sudo apt install -y ca-certificates curl gnupg

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (no need for sudo with docker commands after logout/login)
sudo usermod -aG docker $USER
sudo systemctl enable --now docker

# Log out and log back in for group changes to take effect, or run:
# newgrp docker
```

### Building Standard Image

Build the standard OnionDock image with packaged Tor:

```bash
git clone https://github.com/tn3w/OnionDock.git
cd OnionDock
DOCKER_BUILDKIT=1 docker build -t oniondock -f tor/Dockerfile tor/
```

### Building Tor from Source

For enhanced security or to use the latest Tor version, you can build Tor from source:

```bash
git clone https://github.com/tn3w/OnionDock.git
cd OnionDock
DOCKER_BUILDKIT=1 docker build -t oniondock-from-source -f tor/Dockerfile.tor-from-source tor/
```

> **Note**: Building Tor from source takes significantly longer than using the packaged version. Be patient during the build process.

## Development

### Code Formatting

To format shell scripts in the project:

```bash
# Setup Python environment
python3 -m venv venv
source venv/bin/activate
python3 -m ensurepip

# Install formatting tools
python3 -m pip install beautysh setuptools

# Format all shell scripts
find . -name "*.sh" -exec beautysh {} \;
```

### Project Structure

The project is organized as follows:

```
OnionDock/
├── tor/                      # Tor service configuration
│   ├── config/               # Tor and Vanguards configuration files
│   │   ├── torrc             # Default Tor configuration 
│   │   └── vanguards.conf    # Vanguards configuration
│   ├── Dockerfile            # Docker image with packaged Tor
│   ├── Dockerfile.tor-from-source  # Docker image building Tor from source
│   ├── start.sh              # Tor startup script
│   └── entrypoint.sh         # Docker entrypoint script
├── example/                  # Example application
│   ├── app/                  # Example web application 
│   │   ├── Dockerfile        # Application container definition
│   │   ├── app.py            # Sample web app
│   │   └── ...
│   ├── data/                 # Persistent data directory
│   └── docker-compose.yml    # Example compose file
├── docker-compose.yml        # Base compose file
└── README.md                 # This file
```

## Security Considerations

- **OnionDock Security Scope**: OnionDock enhances Tor's security but is not a silver bullet for all security concerns.
- **Application Security**: Always follow security best practices for your web application; OnionDock only secures the transport layer.
- **Updates**: Keep Docker, Tor, and all components updated to the latest versions to minimize security vulnerabilities.
- **Defense in Depth**: Consider adding additional security layers specific to your application's needs.
- **Isolation**: Run OnionDock on dedicated hardware when possible, especially for sensitive applications.
- **Backup**: Regularly backup your hidden service keys in a secure location.
- **Monitoring**: Implement monitoring to detect unusual patterns or potential attacks.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright 2025 TN3W

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Acknowledgments

- The Tor Project for their incredible work on anonymity technology
- Mike Perry and the Tor Project for the [Vanguards](https://github.com/mikeperry-tor/vanguards) implementation
- The security researchers who developed these security concepts
- The Docker team for container technology that makes this project possible 