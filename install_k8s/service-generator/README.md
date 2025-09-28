# Service Template Generator

A comprehensive templating system for generating microservices based on the console/app pattern. This tool generates complete service structures with Python/Node.js backends, React/Vue/Angular frontends, Docker containers, and Kubernetes deployments.

## Features

### Supported Technologies

**Backend Languages:**
- Python (Flask + SocketIO)
- Node.js (Express + Socket.IO)

**Frontend Languages:**
- React.js
- Vue.js 
- Angular

**Infrastructure:**
- Multi-stage Docker builds
- Kubernetes Helm charts
- OAuth2/OIDC authentication
- HTTPS with cert-manager
- Health checks and monitoring
- Local development with Docker Compose

### Generated Components

Each generated service includes:

1. **Application Code**
   - Backend API with health checks
   - Frontend SPA with authentication
   - Configuration management
   - Authentication middleware

2. **Container Infrastructure**
   - Multi-stage Dockerfile
   - Build and push scripts
   - Docker Compose for local dev

3. **Kubernetes Deployment**
   - Helm chart with templates
   - Ingress with SSL/TLS
   - Service and deployment manifests
   - Health probes and monitoring

4. **Documentation**
   - Comprehensive README
   - API documentation
   - Deployment instructions

## Quick Start

### Installation

```bash
# Clone or download the generator
cd service-generator

# Install dependencies and setup
./install.sh
```

### Generate Your First Service

```bash
# Using configuration file
python3 generate_service.py --config sample_service_config.yaml

# Or using command line arguments
python3 generate_service.py \
  --service-name my-service \
  --backend python \
  --frontend reactjs
```

### Test the Generated Service

```bash
cd generated_services/my-service

# Local development
docker-compose up --build

# Or build and test container
./build.sh
docker run -p 8080:8080 my-service:0.1.0
```

## Configuration

### Configuration File Format

Create a YAML file with your service specification:

```yaml
service:
  name: my-awesome-service
  description: A sample full-stack service
  version: 0.1.0
  port: 8080
  
  backend:
    language: python  # python | nodejs
    port: 8080
  
  frontend:
    language: reactjs  # reactjs | vue | angular
  
  infrastructure:
    registry: registry.gokcloud.com
    namespace: my-awesome-service
    ingress_host: my-awesome-service.gokcloud.com
    enable_https: true
    enable_oauth: true
    oauth_issuer: https://keycloak.gokcloud.com/realms/GokDevelopers
    oauth_client_id: gok-developers-client
```

### Service Patterns

**Full-stack Service:**
```yaml
service:
  name: web-app
  backend:
    language: python
  frontend:
    language: reactjs
```

**API-only Service:**
```yaml
service:
  name: api-service
  backend:
    language: nodejs
    port: 3000
```

**Frontend-only Service:**
```yaml
service:
  name: static-app
  frontend:
    language: vue
  infrastructure:
    enable_oauth: false
```

## Generated Service Structure

```
my-service/
├── Dockerfile                     # Multi-stage container build
├── docker-compose.yml            # Local development
├── build.sh                      # Build script
├── tag_push.sh                   # Registry push script
├── README.md                     # Service documentation
├── backend/                      # Backend application
│   ├── requirements.txt          # Dependencies
│   ├── run.py                    # Entry point
│   └── app/                      # Application code
│       ├── __init__.py           # Flask app factory
│       ├── config.py             # Configuration
│       ├── routes/               # API routes
│       └── auth/                 # Authentication
├── frontend/                     # Frontend application
│   ├── package.json              # Dependencies
│   ├── public/                   # Static assets
│   └── src/                      # Source code
│       ├── App.jsx               # Main component
│       └── components/           # UI components
└── chart/                        # Helm chart
    ├── Chart.yaml                # Chart metadata
    ├── values.yaml               # Configuration
    └── templates/                # K8s manifests
```

## Development Workflow

### 1. Generate Service
```bash
python3 generate_service.py --config my-config.yaml
cd generated_services/my-service
```

### 2. Local Development
```bash
# Start all services
docker-compose up --build

# Or develop components separately
cd backend && python run.py
cd frontend && npm start
```

### 3. Customize and Extend
- Add API endpoints in `backend/app/routes/`
- Add React components in `frontend/src/components/`
- Update configuration in `backend/app/config.py`
- Modify Helm values in `chart/values.yaml`

### 4. Deploy to Kubernetes
```bash
# Build and push
./build.sh
./tag_push.sh

# Deploy with Helm
helm install my-service ./chart
```

## Template Customization

### Adding New Backend Languages

1. Update `backend_configs` in `generate_service.py`
2. Create template files in `templates/backend/newlang/`
3. Add language-specific Dockerfile sections

### Adding New Frontend Frameworks

1. Update `frontend_configs` in `generate_service.py`
2. Create template files in `templates/frontend/newframework/`
3. Update Dockerfile build stages

### Customizing Templates

Templates use Jinja2 syntax with these context variables:

- `service_name` - Original service name
- `service_name_kebab` - kebab-case version
- `service_name_snake` - snake_case version
- `service_name_camel` - CamelCase version
- `backend_language` - Backend language choice
- `frontend_language` - Frontend language choice
- `enable_oauth` - OAuth configuration flag
- `registry` - Container registry URL

## Advanced Features

### OAuth/OIDC Integration

When `enable_oauth: true`, services include:
- JWT token validation middleware
- Protected API endpoints
- Frontend authentication flow
- User context in requests

### Kubernetes Features

- **Health Checks**: Liveness and readiness probes
- **Ingress**: NGINX with SSL/TLS termination
- **Monitoring**: Prometheus metrics endpoints
- **Scaling**: HorizontalPodAutoscaler support
- **Security**: Pod security contexts and RBAC

### Multi-Environment Support

Configure different environments in Helm values:

```yaml
# values-dev.yaml
ingress:
  hosts:
    - host: my-service-dev.gokcloud.com

# values-prod.yaml  
ingress:
  hosts:
    - host: my-service.gokcloud.com
autoscaling:
  enabled: true
  minReplicas: 3
```

## Command Reference

### Generator Commands

```bash
# Generate from config file
python3 generate_service.py --config service.yaml

# Generate from CLI args
python3 generate_service.py --service-name NAME --backend LANG --frontend LANG

# Create sample config
python3 generate_service.py --create-sample

# Custom output directory
python3 generate_service.py --config service.yaml --output-dir /path/to/output
```

### Service Commands (Generated)

```bash
# Build container
./build.sh

# Push to registry
./tag_push.sh

# Local development
docker-compose up

# Kubernetes deployment
helm install SERVICE ./chart
helm upgrade SERVICE ./chart --set image.tag=NEW_VERSION
```

## Troubleshooting

### Common Issues

**Template not found errors:**
- Check template directory structure
- Verify language is supported

**Docker build failures:**
- Ensure Docker daemon is running
- Check proxy settings in build args

**OAuth authentication errors:**
- Verify issuer URL and client ID
- Check JWKS endpoint connectivity

**Kubernetes deployment issues:**
- Validate Helm chart syntax: `helm lint ./chart`
- Check resource quotas and limits

### Debug Commands

```bash
# Check generated files
find generated_services/my-service -type f | head -20

# Test template rendering
python3 -c "from generate_service import ServiceGenerator; g = ServiceGenerator(); print(g.prepare_template_context({'service': {'name': 'test'}}))"

# Validate Helm chart
helm template my-service ./chart | kubectl apply --dry-run=client -f -
```

## Contributing

### Adding Features

1. Fork the repository
2. Add new template files or update existing ones
3. Update the generator configuration
4. Test with sample services
5. Submit a pull request

### Template Guidelines

- Use meaningful variable names
- Include comprehensive error handling
- Follow security best practices
- Document template variables
- Test with multiple configurations

## License

This project is licensed under the MIT License.

---

**Service Template Generator v1.0**
- **Author**: GokCloud Team
- **Documentation**: Generated services include comprehensive READMEs
- **Support**: Check generated service documentation for deployment help