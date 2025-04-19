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

### Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/tn3w/OnionDock.git
   cd OnionDock
   ```

2. Add your web application to the appropriate directory or modify the docker-compose.yml to include your application container.

3. Start the services:
   ```
   docker-compose up -d
   ```

4. Your Tor hidden service address will be available in the logs:
   ```
   docker-compose logs tor
   ```

### Building Individual Components

1. Build just the Tor component with a custom tag:
   ```
   docker build -t oniondock -f tor/Dockerfile tor/
   ```

2. Build and run the example web application:
   ```
   cd example
   docker-compose up -d
   ```

3. Check the status of your hidden service:
   ```
   docker-compose logs -f
   ```

Quick test command:
```bash
sudo docker build -t oniondock -f tor/Dockerfile tor/ && cd example && sudo docker-compose down && sudo docker-compose up -d && docker-compose logs -f
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

OnionDock can be customized through environment variables:

- `TOR_THREADS`: Number of threads for Tor (default: auto-detected)
- `HIDDEN_SERVICE_PORT`: The port to expose (default: 80)
- `SECURITY_LEVEL`: Level of security guards (default: high)
  - `high`: All security components enabled, running in parallel
  - `medium`: Basic security components without circuit build time verification
  - `low`: Minimal security with only vanguards layer protection

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