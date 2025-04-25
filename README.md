```
             @@@@@                                                                
       @@@@@@@@@@@@@@@@@                                                          
    @@@@@@@@@@@@@@@   @@@@@                                                       
  @@@@@@@@@@@@@@ @@@@@@  @@@@                                                     
 @@@@@@@@@@@@@@@@@@  @@@@  @@@   .d88b.       w             888b.            8    
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   8P  Y8 8d8b. w .d8b. 8d8b. 8   8 .d8b. .d8b 8.dP 
@@@@@@@@@@@@@@@@   @@  @@@  @@@  8b  d8 8P Y8 8 8' .8 8P Y8 8   8 8' .8 8    88b  
 @@@@@@@@@@@@@@@ @@@@  @@@ @@@   `Y88P' 8   8 8 `Y8P' 8   8 888P' `Y8P' `Y8P 8 Yb 
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
  - Runs Vanguards using PyPy for significantly enhanced performance

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

```mermaid
graph LR
    subgraph DockerNetwork["Docker Network"]
        style DockerNetwork fill:#1a1a2e,stroke:#4d4dff,stroke-width:2px,color:#e6e6ff
        
        subgraph TorService["Tor Service"]
            style TorService fill:#581845,stroke:#900C3F,stroke-width:2px,color:#ffd1dc
            
            Tor[("Tor Daemon")]
            style Tor fill:#6d214f,stroke:#b33939,stroke-width:2px,color:#ffd1dc
            
            VG["Vanguards"]
            style VG fill:#3c162f,stroke:#e84393,stroke-width:1px,color:#ffb8d9,shape:hexagon
        end
        
        App["Your App"]
        style App fill:#16213e,stroke:#0099ff,stroke-width:2px,color:#8fd6ff
    end
    
    subgraph ExternalOptions["External Services (Optional)"]
        style ExternalOptions fill:#1e1e30,stroke:#666666,stroke-width:1px,stroke-dasharray: 5 5,color:#e6e6ff
        
        DB[(PostgreSQL)]
        style DB fill:#1f3b2c,stroke:#5cb85c,stroke-width:2px,color:#9af5b1
        
        OtherDB[("Other Databases<br>(MySQL, MongoDB, etc)")]
        style OtherDB fill:#2d2d3e,stroke:#8a8aff,stroke-width:2px,color:#c4c4ff
        
        ExternalAPI["External APIs"]
        style ExternalAPI fill:#2b2133,stroke:#b366ff,stroke-width:2px,color:#e6ccff
    end
    
    Internet(("Internet via<br>Tor Network"))
    style Internet fill:#2d1d42,stroke:#9966ff,stroke-width:2px,color:#d8c2ff
    
    Tor -->|"forwards"| App
    App -->|"responses"| Tor
    App -.->|"optional<br>connections"| ExternalOptions
    Tor -->|"routes through"| Internet
    Tor --- VG
    
    classDef node rx:5,ry:5;
    classDef label color:#cccccc,font-size:12px;
```

**Vanguards Integration**

OnionDock includes the official [Vanguards](https://github.com/mikeperry-tor/vanguards) security enhancements for Tor, running on PyPy for improved performance. The Vanguards suite provides protection against various attacks on Tor hidden services:

- **How it works in OnionDock:**
  - Runs multiple security components in parallel for better resource utilization
  - Configurable security levels (high/medium/low) via `SECURITY_LEVEL` environment variable
  - In high security mode (default), all three modules run simultaneously:
    - **Vanguards Module**: Protects against guard discovery attacks
    - **BandGuards Module**: Mitigates bandwidth side-channel attacks
    - **RendGuards Module**: Protects against rendezvous point enumeration

The Tor service is hardened with these security enhancements while maintaining compatibility with any containerized web application, providing strong security with minimal configuration.

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

2. **Build and start the services**:
   ```bash
   docker compose up -d
   ```

3. **Get your Tor hidden service address**:
   ```bash
   docker compose logs tor | grep "Tor hidden service"
   ```

   You should see output similar to:
   ```
   [+] Tor hidden service at: abcdefghijklmnopqrstuvwxyz234567.onion
   ```

4. **Access your hidden service**:
   
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
       environment:
         # Format: TOR_PORT:SERVICE_NAME:SERVICE_PORT
         # Multiple services can be comma-separated
         - TOR_SERVICE_PORTS=80:your-app-service:3000
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

3. **Start your services**:
   ```bash
   docker compose up -d
   ```

4. **Get your Tor hidden service address**:
   ```bash
   docker compose logs tor | grep "Tor hidden service"
   ```

### Configure Hidden Service Ports

OnionDock makes it easy to configure port mappings between your Tor hidden service and your application services using the `TOR_SERVICE_PORTS` environment variable.

The format is: `TOR_PORT:SERVICE_NAME:SERVICE_PORT`

For multiple port mappings, separate them with commas:

```yaml
services:
  tor:
    image: tn3w/oniondock:latest
    environment:
      # Map multiple services and ports
      - TOR_SERVICE_PORTS=80:web-app:8080,8888:admin-panel:3000,22:ssh-service:22
    # ...other configuration
```

This configuration will:
- Map port 80 on your .onion address to port 8080 on the web-app service
- Map port 8888 on your .onion address to port 3000 on the admin-panel service
- Map port 22 on your .onion address to port 22 on the ssh-service service

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
      - TOR_SERVICE_PORTS=80:webapp:8080
    # ...other configuration
```

### Advanced Tor Configuration

For advanced Tor configuration beyond port mapping, you can still mount a custom torrc file:

```yaml
services:
  tor:
    image: oniondock:latest
    environment:
      - TOR_SERVICE_PORTS=80:webapp:8080,8888:admin:3000
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

# Security enhancements
StrictNodes 1
EnforceDistinctSubnets 1
WarnUnsafeSocks 1
```

> **Note**: When using a custom torrc file, make sure it includes the line `# PORTS` where the port configurations should be inserted. Port mappings are dynamically generated from the `TOR_SERVICE_PORTS` environment variable.

## Building from Source

If you prefer to build the OnionDock images locally rather than using the pre-built Docker Hub images, follow these instructions.

### Installing Prerequisites

#### Installing Prerequisites on Ubuntu

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install Git
sudo apt install -y git

# Install Docker prerequisites
sudo apt install -y ca-certificates curl gnupg

# Install Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Create Docker repository configuration
echo "deb [arch=$(dpkg --print-architecture) \
     signed-by=/etc/apt/keyrings/docker.asc] \
     https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") \
     stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists with new repository
sudo apt-get update

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