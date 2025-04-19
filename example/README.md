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
├── docker-compose.yml     # Docker Compose configuration
└── README.md              # This file
```