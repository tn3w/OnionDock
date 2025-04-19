# OnionDock: Secure Tor Hidden Service Deployment

OnionDock is a turnkey solution for deploying web applications as Tor hidden services with enhanced security, reliability and performance.

## Purpose

OnionDock provides a pre-configured Docker environment with a hardened Tor instance that includes security enhancements from the official [Vanguards](https://github.com/mikeperry-tor/vanguards) project. It enables developers to quickly deploy their web applications on the Tor network with minimal configuration while maintaining strong security practices.

## Features

- **Secure Tor Configuration**: Hardened Tor instance with security best practices
- **Official Security Enhancements**:
  - **Vanguards**: Protection against guard discovery attacks
  - **BandGuard**: Mitigation of bandwidth side-channel attacks
  - **RendGuard**: Protection against rendezvous point enumeration attacks
  - **CbtVerify**: Detection of circuit build time anomalies
  - **DropTimeouts**: Dropping circuits that timeout in certain states
- **Performance Optimized**: 
  - Automatic multi-threading for improved Tor performance
  - Parallel execution of Vanguards components for better CPU utilization
- **Easy Integration**: Simple port sharing between your web application and the Tor hidden service
- **Modular Design**: Easily add your own web applications, load balancers, Redis, or other services
- **Docker-based**: Containerized for consistent deployment across environments

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your system
- Basic understanding of Docker containers and networks

#### Installing Prerequisites on Ubuntu/Debian

```bash
# Update package lists
sudo apt update
sudo apt upgrade -y

# Install Git
sudo apt install -y git

# Install Docker
sudo apt install -y docker.io
sudo apt install -y docker-compose python3-distutils
sudo apt install -y docker-buildx
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

### Quick Start

1. Clone this repository and enter the directory:
   ```bash
   git clone https://github.com/tn3w/OnionDock.git
   cd OnionDock
   ```

2. Stop any existing containers:
   ```bash
   sudo docker-compose down
   ```

3. Build the oniondock image:
   ```bash
   DOCKER_BUILDKIT=1 sudo docker build -t oniondock -f tor/Dockerfile tor/
   ```

4. Change to the example directory and start the services:
   ```bash
   cd example
   DOCKER_BUILDKIT=1 sudo docker build -t webapp .
   sudo docker-compose up -d
   ```

5. Get your Tor hidden service address:
   ```bash
   docker-compose logs tor | grep "Tor hidden service at"
   ```

Quick command:
```bash
git clone https://github.com/tn3w/OnionDock.git && cd OnionDock && sudo docker-compose down && DOCKER_BUILDKIT=1 sudo docker build -t oniondock -f tor/Dockerfile tor/ && cd example && DOCKER_BUILDKIT=1 sudo docker build -t webapp . && sudo docker-compose up -d && docker-compose logs tor | grep "Tor hidden service at"
```

## Formatting start.sh

```bash
python3 -m venv venv
source venv/bin/activate
python3 -m ensurepip
python3 -m pip install beautysh setuptools
beautysh tor/start.sh
```

## Usage Examples

### Deploying a Simple Web Application

```yaml
# Add to docker-compose.yml
services:
  webapp:
    image: nginx:latest
    volumes:
      - ./my-website:/usr/share/nginx/html
    networks:
      - onion_network

  # The OnionDock services will automatically connect your webapp
```

### Adding a Load Balancer

```yaml
services:
  load_balancer:
    image: nginx:latest
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    networks:
      - onion_network
    depends_on:
      - webapp1
      - webapp2
```

## Architecture

OnionDock consists of the following components:

- **Tor Service**: A hardened Tor instance with enhanced security modules
- **Vanguards Addon**: 
  - Official security implementation from the [Vanguards](https://github.com/mikeperry-tor/vanguards) project
  - Components (Vanguards, BandGuards, RendGuards) run in parallel processes for better performance
- **Network Bridge**: Connects your application containers to the Tor service
- **Volume Mounts**: For persistence of Tor keys and configurations

## Security Considerations

- OnionDock enhances Tor's security but is not a silver bullet for all security concerns
- Always follow security best practices for your web application
- Keep Docker and all components updated to the latest versions
- Consider adding additional security layers specific to your application's needs

## Configuration Options

### Adding Tor Port Forward

To forward traffic from your Tor hidden service to your web application, add the following configuration to your `torrc` file:

```t
# ...
HiddenServiceDir /var/lib/tor/hidden_service
HiddenServiceVersion 3

# For example, if your docker container named "webapp" is running on port 8080 and you want to forward http traffic to it
HiddenServicePort 80 webapp:8080
# ...
```

### Security Level

OnionDock can be customized through environment variables:

- `SECURITY_LEVEL`: Level of security guards (default: high)
  - `high`: All security components enabled, running in parallel
  - `medium`: Basic security components without circuit build time verification
  - `low`: Minimal security with only vanguards layer protection

Example docker-compose.yml:
```yaml
services:
  tor:
    # ...
    environment:
      - SECURITY_LEVEL=high
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

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