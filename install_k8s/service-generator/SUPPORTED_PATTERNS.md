# Service Generator - Supported Patterns Documentation

## Overview

The Service Generator is a templating system that codifies proven microservice patterns into reusable templates. It supports multiple application architectures, technology stacks, and deployment patterns based on modern containerization and Kubernetes orchestration.

## Application Architecture Patterns

### 1. Full-Stack Microservice Pattern

**Description**: Complete web application with both backend API and frontend UI in a single deployable unit.

**Use Cases**:
- Web applications with tightly coupled frontend and backend
- Admin dashboards and management interfaces  
- Customer-facing applications requiring real-time features
- Applications where frontend and backend are developed by the same team

**Technology Combinations**:
```yaml
# Python + React
service:
  name: web-dashboard
  description: Admin dashboard with Python API
  backend:
    language: python
    port: 8080
  frontend:
    language: reactjs
  infrastructure:
    enable_oauth: true

# Node.js + Vue
service:
  name: customer-portal
  description: Customer portal with Node.js backend
  backend:
    language: nodejs
    port: 3000
  frontend:
    language: vue
```

**Generated Structure**:
```
service-name/
├── Dockerfile              # Multi-stage build (frontend + backend)
├── backend/                # API application
│   ├── run.py             # Python entry point
│   └── app/               # Flask application
├── frontend/              # SPA application  
│   ├── package.json       # React/Vue dependencies
│   └── src/               # Frontend source code
└── chart/                 # Single Helm chart for both
```

**Deployment**: Single Kubernetes deployment serving both API and static files.

### 2. API-Only Service Pattern

**Description**: Backend microservice exposing REST APIs without frontend components.

**Use Cases**:
- Business logic microservices
- Data processing services
- Integration APIs and webhooks
- Services consumed by multiple frontend applications
- Internal APIs for service-to-service communication

**Technology Options**:
```yaml
# Python Flask API
service:
  name: user-service
  description: User management API
  backend:
    language: python
    port: 8080
  infrastructure:
    enable_oauth: true

# Node.js Express API
service:
  name: notification-service  
  description: Notification processing service
  backend:
    language: nodejs
    port: 3000
```

**Generated Structure**:
```
service-name/
├── Dockerfile              # Backend-only container
├── backend/                # API application
│   ├── requirements.txt    # Dependencies
│   ├── run.py             # Entry point
│   └── app/               # Application logic
│       ├── routes/        # API endpoints
│       └── auth/          # Authentication middleware
└── chart/                 # Kubernetes deployment
```

**Features**:
- OpenAPI/Swagger documentation (`/api/docs/`)
- Health check endpoints (`/health`, `/health/ready`, `/health/live`)
- JWT authentication middleware (if OAuth enabled)
- Prometheus metrics integration
- Structured logging

### 3. Frontend-Only Service Pattern

**Description**: Static frontend applications served without backend components.

**Use Cases**:
- Static websites and marketing pages
- Client-side applications consuming external APIs
- Micro-frontends in larger applications
- Documentation sites and portals
- Applications with backend-as-a-service

### 4. Agent-Controller Distributed Pattern

**Description**: Distributed system with a central controller that manages multiple worker agents via message queues. The controller provides a web interface for task submission, while agents execute tasks and stream results back in real-time.

**Use Cases**:
- Distributed command execution systems
- Remote automation and orchestration
- Cluster management and monitoring
- CI/CD pipeline execution
- Multi-node data processing
- Infrastructure automation
- Remote debugging and diagnostics
- Distributed testing frameworks

**Architecture Components**:
```yaml
# Agent-Controller Pattern
service:
  name: task-executor
  pattern: agent-controller
  
  controller:
    backend:
      language: python
      port: 8080
    frontend:
      language: reactjs
    
  agent:
    language: python
    privileged: true
    
  messaging:
    rabbitmq:
      enabled: true
```

**Generated Structure**:
```
service-name/
├── controller/
│   ├── Dockerfile              # Controller container
│   ├── controller.py           # Flask + SocketIO backend
│   ├── requirements.txt        # Controller dependencies
│   └── frontend/               # React management UI
│       ├── package.json
│       └── src/
│           ├── App.jsx         # Real-time task monitoring
│           └── components/
│               └── TaskMonitor.jsx
├── agent/
│   ├── Dockerfile              # Agent container
│   ├── agent.py               # Worker agent
│   └── requirements.txt        # Agent dependencies
└── chart/                      # Kubernetes deployment
    ├── values.yaml            # Multi-service configuration
    └── templates/             # Controller + Agent deployments
```

**Key Features**:
- **Real-time Communication**: WebSocket streaming of task results
- **Message Queue Integration**: RabbitMQ for reliable task distribution
- **RBAC Support**: Role-based command authorization
- **OAuth2 Authentication**: JWT token validation for secure access
- **Privileged Execution**: Agents can run with elevated permissions
- **Multi-node Deployment**: Agents distributed across cluster nodes
- **Live Monitoring**: Web UI for task submission and result tracking
- **Fault Tolerance**: Message persistence and agent reconnection

**Technology Options**:
```yaml
# React SPA
service:
  name: marketing-site
  description: Company marketing website
  frontend:
    language: reactjs
  infrastructure:
    enable_oauth: false

# Vue.js Application  
service:
  name: admin-ui
  description: Administrative interface
  frontend:
    language: vue
  infrastructure:
    enable_oauth: true
```

**Generated Structure**:
```
service-name/
├── Dockerfile              # Static file serving (nginx)
├── frontend/               # SPA application
│   ├── package.json       # Dependencies
│   ├── public/            # Static assets
│   └── src/               # Source code
└── chart/                 # Kubernetes deployment
```

**Deployment**: Nginx container serving built static files.

## Technology Stack Patterns

### Backend Technology Patterns

#### Python Flask Pattern
```yaml
backend:
  language: python
  port: 8080
```

**Generated Components**:
- **Framework**: Flask with Flask-RestX for API documentation
- **Authentication**: JWT validation with python-jose
- **WebSocket**: Flask-SocketIO for real-time features
- **Production Server**: Gunicorn WSGI server
- **API Documentation**: Swagger UI at `/api/docs/`
- **Dependencies**: Marshmallow, CORS, Werkzeug
- **Health Checks**: Comprehensive system monitoring

**File Structure**:
```
backend/
├── requirements.txt        # Python dependencies
├── run.py                 # Application entry point
└── app/
    ├── __init__.py        # Flask app factory
    ├── config.py          # Configuration management
    ├── routes/            # API route handlers
    │   ├── __init__.py
    │   └── health.py      # Health check endpoints
    └── auth/              # Authentication components
        └── middleware.py  # JWT validation
```

#### Node.js Express Pattern
```yaml
backend:
  language: nodejs
  port: 3000
```

**Generated Components**:
- **Framework**: Express.js with CORS
- **WebSocket**: Socket.IO integration
- **Environment**: dotenv configuration
- **Production**: PM2 process management ready
- **Dependencies**: Express, CORS, Socket.IO

### Frontend Technology Patterns

#### React.js Pattern
```yaml
frontend:
  language: reactjs
```

**Generated Components**:
- **Framework**: Create React App (CRA)
- **Routing**: React Router DOM
- **HTTP Client**: Axios with interceptors
- **WebSocket**: Socket.IO client
- **UI Framework**: Bootstrap integration
- **Authentication**: OAuth2 flow implementation

**File Structure**:
```
frontend/
├── package.json           # Dependencies and scripts
├── public/
│   └── index.html        # HTML template
└── src/
    ├── index.jsx         # Application entry point
    ├── App.jsx           # Main application component
    └── components/
        └── Header.jsx    # Navigation component
```

#### Vue.js Pattern
```yaml
frontend:
  language: vue
```

**Generated Components**:
- **Build System**: Vite for fast development
- **Framework**: Vue 3 with Composition API
- **Routing**: Vue Router 4
- **HTTP Client**: Axios integration

#### Angular Pattern
```yaml
frontend:
  language: angular
```

**Generated Components**:
- **Framework**: Angular 15+ with Angular CLI
- **Reactive**: RxJS for state management
- **Routing**: Angular Router
- **HTTP Client**: Angular HttpClient

## Infrastructure Patterns

### Container Patterns

#### Multi-Stage Docker Build Pattern
For full-stack services:
```dockerfile
# Stage 1: Frontend build
FROM node:20 AS frontend-builder
COPY frontend/ ./
RUN npm install && npm run build

# Stage 2: Backend build  
FROM python:3.11 AS backend-builder
COPY backend/requirements.txt ./
RUN pip install -r requirements.txt

# Stage 3: Production
FROM python:3.11-slim
COPY --from=frontend-builder /frontend/build ./static/
COPY backend/ ./
RUN pip install -r requirements.txt
CMD ["gunicorn", "run:app"]
```

#### Single-Stage Build Pattern
For backend-only or frontend-only services:
```dockerfile
# Backend only
FROM python:3.11-slim
COPY backend/ ./
RUN pip install -r requirements.txt
CMD ["gunicorn", "run:app"]

# Frontend only
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html/
```

### Kubernetes Deployment Patterns

#### Standard Microservice Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-name
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: app
        image: registry/namespace/service:version
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
```

#### Ingress with SSL/TLS Pattern
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy/oauth2/auth"
spec:
  tls:
  - secretName: service-tls
    hosts:
    - service.domain.com
  rules:
  - host: service.domain.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: service-name
            port:
              number: 80
```

### Authentication Patterns

#### OAuth2/OIDC Pattern
```yaml
infrastructure:
  enable_oauth: true
  oauth_issuer: https://keycloak.domain.com/realms/MyRealm
  oauth_client_id: my-client-id
```

**Generated Components**:
- **Backend**: JWT validation middleware with JWKS integration
- **Frontend**: OAuth2 authorization flow implementation  
- **Kubernetes**: OAuth2-proxy integration via ingress annotations
- **Security**: Role-based access control decorators

**Authentication Flow**:
1. User clicks login in frontend
2. Redirect to OAuth provider (Keycloak)
3. User authenticates and approves
4. Redirect back with authorization code
5. Exchange code for JWT token
6. Store token and use for API calls
7. Backend validates JWT on each request

#### No Authentication Pattern
```yaml
infrastructure:
  enable_oauth: false
```

**Generated Components**:
- **Backend**: Placeholder auth decorators (no-op)
- **Frontend**: No authentication UI components
- **Open Access**: All endpoints publicly accessible

## Development Patterns

### Local Development Pattern

**Docker Compose Setup**:
```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - FLASK_ENV=development
    volumes:
      - ./backend:/app
      - ./frontend:/frontend
```

**Development Workflow**:
1. `docker-compose up --build` - Start local environment
2. Backend runs with hot reload
3. Frontend served with development server
4. Environment variables configured for local testing

### Production Deployment Pattern

**Build and Deploy Workflow**:
```bash
# 1. Build container
./build.sh

# 2. Push to registry  
./tag_push.sh

# 3. Deploy to Kubernetes
helm install service-name ./chart

# 4. Upgrade deployment
helm upgrade service-name ./chart --set image.tag=new-version
```

## Configuration Patterns

### Service Configuration Schema
```yaml
service:
  name: string              # Service name (required)
  description: string       # Service description
  version: string          # Semantic version (default: 0.1.0)
  port: integer            # External port (default: 8080)
  
  backend:                 # Optional backend configuration
    language: enum         # python | nodejs
    port: integer          # Backend port
    
  frontend:               # Optional frontend configuration  
    language: enum        # reactjs | vue | angular
    
  infrastructure:         # Infrastructure configuration
    registry: string      # Container registry URL
    namespace: string     # Registry namespace/organization
    ingress_host: string  # Domain name for ingress
    enable_https: boolean # SSL/TLS certificate (default: true)
    enable_oauth: boolean # OAuth2 authentication (default: true)
    oauth_issuer: string  # OIDC issuer URL
    oauth_client_id: string # OAuth2 client ID
  
  # Agent-Controller Pattern Specific
  controller:             # Controller component configuration
    backend:              # Controller backend settings
      language: python    # Backend runtime (python)
      port: integer       # Controller API port (default: 8080)
    frontend:             # Controller web interface
      language: reactjs   # Frontend framework (reactjs)
  
  agent:                  # Agent component configuration
    language: python      # Agent runtime (python)
    privileged: boolean   # Run with elevated permissions (default: false)
  
  messaging:              # Message queue configuration
    rabbitmq:             # RabbitMQ settings
      enabled: boolean    # Enable message queue (default: true)
```

### Environment-Specific Patterns

#### Development Configuration
```yaml
service:
  name: my-service-dev
  infrastructure:
    ingress_host: my-service-dev.internal.com
    enable_oauth: false  # Simplified for development
```

#### Production Configuration  
```yaml
service:
  name: my-service
  infrastructure:
    ingress_host: my-service.company.com
    enable_oauth: true
    enable_https: true
```

#### Agent-Controller Configuration
```yaml
service:
  name: distributed-executor
  pattern: agent-controller
  
  controller:
    backend:
      language: python
      port: 8080
    frontend:
      language: reactjs
  
  agent:
    language: python
    privileged: true
  
  messaging:
    rabbitmq:
      enabled: true
  
  infrastructure:
    ingress_host: executor.company.com
    enable_oauth: true
    oauth_issuer: "https://auth.company.com"
    oauth_client_id: "distributed-executor"
```

## Service Communication Patterns

### Synchronous Communication
- **REST APIs**: HTTP/HTTPS with JSON
- **Authentication**: JWT tokens in Authorization headers
- **Documentation**: OpenAPI/Swagger specifications
- **Health Checks**: Standard endpoints for monitoring

### Asynchronous Communication  
- **WebSocket**: Real-time bidirectional communication
- **Socket.IO**: Cross-platform WebSocket with fallbacks
- **Event Handling**: Frontend and backend event systems

### Service Discovery
- **Kubernetes DNS**: Automatic service discovery
- **Ingress Routing**: External access via domain names
- **Health Probes**: Kubernetes-native health checking

## Monitoring and Observability Patterns

### Health Check Pattern
```python
@app.route('/health')
def health_check():
    return {'status': 'healthy', 'timestamp': datetime.utcnow()}

@app.route('/health/ready')  
def readiness_probe():
    # Check dependencies (database, external services)
    return {'status': 'ready'}

@app.route('/health/live')
def liveness_probe():
    return {'status': 'alive'}
```

### Metrics Pattern
- **Prometheus Integration**: Metrics endpoints
- **System Metrics**: CPU, memory, disk usage
- **Application Metrics**: Request counts, response times
- **Custom Metrics**: Business-specific measurements

### Logging Pattern
- **Structured Logging**: JSON format for parsing
- **Log Levels**: DEBUG, INFO, WARNING, ERROR
- **Context**: Request IDs, user context, timestamps
- **Centralized**: Kubernetes log aggregation ready

## Security Patterns

### Container Security
- **Multi-stage Builds**: Minimal production images
- **Non-root User**: Security contexts in Kubernetes  
- **Secret Management**: Kubernetes secrets integration
- **Network Policies**: Restricted pod-to-pod communication

### Application Security
- **JWT Validation**: Cryptographic token verification
- **CORS Configuration**: Cross-origin request handling
- **Input Validation**: Request data sanitization
- **HTTPS Enforcement**: TLS termination at ingress

### Infrastructure Security
- **RBAC**: Role-based access control in Kubernetes
- **Pod Security**: Security contexts and policies
- **Secret Rotation**: External secret management integration
- **Network Segmentation**: Namespace isolation

---

## Pattern Selection Guide

### Choose Full-Stack Pattern When:
- Frontend and backend are tightly coupled
- Single team owns both components  
- Real-time features require WebSocket communication
- Simplified deployment is preferred

### Choose API-Only Pattern When:
- Multiple frontends consume the same API
- Service provides business logic to other services
- Clear separation between frontend and backend teams
- Microservice architecture is preferred

### Choose Frontend-Only Pattern When:
- Static content or documentation sites
- Client-side applications with external APIs
- Micro-frontend architecture
- Content management or marketing sites

### Choose Python Backend When:
- Data processing and analytics
- Machine learning integration
- Rapid prototyping and development
- Rich ecosystem of libraries needed

### Choose Node.js Backend When:  
- High concurrency requirements
- Real-time applications
- JavaScript expertise in team
- NPM ecosystem utilization

### Choose React Frontend When:
- Complex interactive interfaces
- Large developer ecosystem
- Component reusability important
- Strong typing with TypeScript

### Choose Vue Frontend When:
- Gradual adoption in existing projects
- Simpler learning curve preferred
- Rapid development cycles
- Smaller bundle sizes needed

This documentation provides a comprehensive guide to all patterns supported by the Service Generator, helping teams select the right architectural approach for their specific requirements.
