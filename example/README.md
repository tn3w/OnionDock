# OnionDock Example Application

This is a simple example of deploying a Python Flask application as a Tor hidden service using OnionDock.

## What's Included

- A basic Flask web application that displays "Hello, Tor!"
- Docker configuration to run the application with OnionDock
- Network configuration to expose the app through Tor

## Directory Structure

```
example/
├── app/                   # The Flask application
│   ├── app.py             # Main application code
│   ├── Dockerfile         # Docker configuration for the app
│   ├── requirements.txt   # Python dependencies
│   └── templates/         # HTML templates
│       └── index.html     # The page that displays "Hello, Tor!"
├── data/                  # Persistent data directory
│   └── tor/               # Tor data
│       └── hidden_service/# Hidden service keys and hostname
├── docker-compose.yml     # Docker Compose configuration
└── README.md              # This file
```

## Deployment Instructions

Follow these steps to deploy the example application:

### Prerequisites

- Docker and Docker Compose installed on your system
- Git (to clone the repository)

### Steps

1. Make sure the data directory for Tor's hidden service exists:

```bash
mkdir -p data/tor/hidden_service
```

2. Ensure the Tor configuration is properly set up:

```bash
cp torrc.example ../tor/config/torrc
```

3. Deploy the application:

```bash
docker-compose up -d
```

4. View your Tor hidden service address:

```bash
docker-compose logs tor | grep "Tor hidden service at" 
```

You should see a line similar to:
```
tor_1    | [+] Hidden service created: abcdefghijklmnopqrstuvwxyz1234567890.onion
```

This `.onion` address is where your application is accessible over the Tor network.

### One-line Deployment Command

For a quick deployment, you can use this one-line command that handles the necessary steps:

```bash
mkdir -p data/tor/hidden_service && cp torrc.example ../tor/config/torrc && docker-compose up -d && echo "Waiting for hidden service to be created..." && sleep 10 && docker-compose logs tor | grep "Hidden service created"
```

### Accessing the Application

To access your application, you need the Tor Browser:

1. Download and install the [Tor Browser](https://www.torproject.org/download/)
2. Open the Tor Browser
3. Navigate to your `.onion` address (from step 4 above)

You should see the "Hello, Tor!" page displayed in your browser.

## Customizing the Application

You can modify the Flask application in the `app` directory. The changes will be reflected automatically due to the volume mounting in the Docker Compose file.

## Security Considerations

This is a basic example for demonstration purposes. For production use, consider:

- Adding authentication to your hidden service
- Implementing additional security layers
- Regularly updating all components

## Troubleshooting

If you encounter issues:

- Check the logs: `docker-compose logs`
- Ensure all containers are running: `docker-compose ps`
- Verify Tor is running properly: `docker-compose logs tor`

## Shutting Down

To stop the application:

```bash
docker-compose down
```

To remove all data including the hidden service key:

```bash
docker-compose down
rm -rf data
```

Note: Removing the data directory will change your `.onion` address when you restart the service. 