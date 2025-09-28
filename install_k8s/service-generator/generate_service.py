#!/usr/bin/env python3
"""
Service Template Generator

This script generates a new service based on the console/app pattern
with configurable backend and frontend languages.

Usage:
    python generate_service.py --config service_config.yaml
    python generate_service.py --service-name my-service --backend python --frontend reactjs
"""

import os
import sys
import yaml
import argparse
import shutil
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, Template
import json

class ServiceGenerator:
    def __init__(self, template_dir="templates", output_dir="generated_services"):
        self.template_dir = Path(template_dir)
        self.output_dir = Path(output_dir)
        self.jinja_env = Environment(loader=FileSystemLoader(self.template_dir))
        
        # Supported language configurations
        self.backend_configs = {
            "python": {
                "runtime": "python:3.11",
                "runtime_slim": "python:3.11-slim",
                "package_manager": "pip",
                "requirements_file": "requirements.txt",
                "main_file": "run.py",
                "default_port": 8080,
                "framework": "Flask",
                "dependencies": [
                    "Flask==3.0.3",
                    "flask-restx==1.3.0",
                    "marshmallow==3.21.1",
                    "PyJWT==2.8.0",
                    "flask-cors==4.0.1",
                    "python-jose==3.3.0",
                    "flask-socketio==5.3.6",
                    "requests==2.31.0",
                    "gunicorn==21.2.0",
                    "Werkzeug>=3.0.0"
                ]
            },
            "nodejs": {
                "runtime": "node:20",
                "runtime_slim": "node:20-slim", 
                "package_manager": "npm",
                "requirements_file": "package.json",
                "main_file": "server.js",
                "default_port": 3000,
                "framework": "Express",
                "dependencies": {
                    "express": "^4.18.2",
                    "cors": "^2.8.5",
                    "dotenv": "^16.0.3",
                    "socket.io": "^4.7.2"
                }
            }
        }
        
        self.frontend_configs = {
            "reactjs": {
                "runtime": "node:20",
                "package_manager": "npm",
                "framework": "React",
                "build_command": "npm run build",
                "dependencies": {
                    "react": "^18.0.0",
                    "react-dom": "^18.0.0",
                    "react-scripts": "5.0.1",
                    "react-router-dom": "^6.8.0",
                    "axios": "^1.3.0",
                    "socket.io-client": "^4.7.2"
                },
                "scripts": {
                    "start": "react-scripts start",
                    "build": "react-scripts build",
                    "test": "react-scripts test",
                    "eject": "react-scripts eject"
                }
            },
            "vue": {
                "runtime": "node:20",
                "package_manager": "npm", 
                "framework": "Vue.js",
                "build_command": "npm run build",
                "dependencies": {
                    "vue": "^3.2.0",
                    "vue-router": "^4.1.0",
                    "axios": "^1.3.0",
                    "@vitejs/plugin-vue": "^4.0.0",
                    "vite": "^4.1.0"
                },
                "scripts": {
                    "dev": "vite",
                    "build": "vite build",
                    "preview": "vite preview"
                }
            },
            "angular": {
                "runtime": "node:20",
                "package_manager": "npm",
                "framework": "Angular", 
                "build_command": "npm run build",
                "dependencies": {
                    "@angular/core": "^15.0.0",
                    "@angular/common": "^15.0.0",
                    "@angular/router": "^15.0.0",
                    "@angular/cli": "^15.0.0",
                    "rxjs": "^7.5.0",
                    "socket.io-client": "^4.7.2"
                },
                "scripts": {
                    "start": "ng serve",
                    "build": "ng build",
                    "test": "ng test"
                }
            }
        }
        
        # Service pattern configurations
        self.service_patterns = {
            "standalone": {
                "description": "Single service with backend and/or frontend",
                "components": ["backend", "frontend"],
                "required": []
            },
            "agent-controller": {
                "description": "Distributed system with controller and worker agents",
                "components": ["controller", "agent"],
                "required": ["rabbitmq"],
                "features": ["real-time", "distributed", "rbac"]
            }
        }
    
    def load_config(self, config_file):
        """Load service configuration from YAML file"""
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    
    def validate_config(self, config):
        """Validate the service configuration"""
        required_fields = ['service']
        for field in required_fields:
            if field not in config:
                raise ValueError(f"Missing required field: {field}")
        
        service = config['service']
        
        # Validate service name
        if 'name' not in service:
            raise ValueError("Service name is required")
        
        # Validate backend configuration
        if 'backend' in service:
            backend_lang = service['backend'].get('language')
            if backend_lang and backend_lang not in self.backend_configs:
                raise ValueError(f"Unsupported backend language: {backend_lang}")
        
        # Validate frontend configuration  
        if 'frontend' in service:
            frontend_lang = service['frontend'].get('language')
            if frontend_lang and frontend_lang not in self.frontend_configs:
                raise ValueError(f"Unsupported frontend language: {frontend_lang}")
    
    def prepare_template_context(self, config):
        """Prepare context variables for template rendering"""
        service = config['service']
        
        context = {
            'service_name': service['name'],
            'service_name_kebab': service['name'].lower().replace('_', '-'),
            'service_name_snake': service['name'].lower().replace('-', '_'),
            'service_name_camel': ''.join(word.capitalize() for word in service['name'].replace('-', '_').split('_')),
            'description': service.get('description', f"A {service['name']} service"),
            'version': service.get('version', '0.1.0'),
            'port': service.get('port', 8080),
            'has_backend': 'backend' in service,
            'has_frontend': 'frontend' in service,
            'service_pattern': service.get('pattern', 'standalone'),
            'is_agent_controller': service.get('pattern') == 'agent-controller',
            'has_controller': service.get('pattern') == 'agent-controller' and 'controller' in service,
            'has_agent': service.get('pattern') == 'agent-controller' and 'agent' in service,
        }
        
        # Backend configuration
        if 'backend' in service:
            backend_lang = service['backend']['language']
            backend_config = self.backend_configs[backend_lang]
            context.update({
                'backend_language': backend_lang,
                'backend_runtime': backend_config['runtime'],
                'backend_runtime_slim': backend_config['runtime_slim'],
                'backend_framework': backend_config['framework'],
                'backend_port': service['backend'].get('port', backend_config['default_port']),
                'backend_main_file': backend_config['main_file'],
                'backend_requirements_file': backend_config['requirements_file'],
                'backend_dependencies': backend_config['dependencies'],
                'backend_package_manager': backend_config['package_manager']
            })
        
        # Frontend configuration
        if 'frontend' in service:
            frontend_lang = service['frontend']['language']
            frontend_config = self.frontend_configs[frontend_lang]
            context.update({
                'frontend_language': frontend_lang,
                'frontend_runtime': frontend_config['runtime'],
                'frontend_framework': frontend_config['framework'],
                'frontend_build_command': frontend_config['build_command'],
                'frontend_dependencies': frontend_config['dependencies'],
                'frontend_scripts': frontend_config['scripts'],
                'frontend_package_manager': frontend_config['package_manager']
            })
        
        # Infrastructure configuration
        infra = service.get('infrastructure', {})
        context.update({
            'registry': infra.get('registry', 'registry.gokcloud.com'),
            'namespace': infra.get('namespace', service['name']),
            'ingress_host': infra.get('ingress_host', f"{service['name']}.gokcloud.com"),
            'enable_https': infra.get('enable_https', True),
            'enable_oauth': infra.get('enable_oauth', True),
            'oauth_issuer': infra.get('oauth_issuer', 'https://keycloak.gokcloud.com/realms/GokDevelopers'),
            'oauth_client_id': infra.get('oauth_client_id', 'gok-developers-client')
        })
        
        return context
    
    def generate_file_from_template(self, template_path, output_path, context):
        """Generate a single file from template"""
        try:
            template = self.jinja_env.get_template(str(template_path))
            rendered_content = template.render(**context)
            
            # Create directory if it doesn't exist
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write rendered content
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(rendered_content)
            
            print(f"Generated: {output_path}")
            
        except Exception as e:
            print(f"Error generating {output_path}: {str(e)}")
            raise
    
    def copy_static_files(self, service_dir, context):
        """Copy static files that don't need templating"""
        static_files = [
            'backend/app/config.py',
            'backend/app/auth/__init__.py',
            'frontend/public/favicon.ico',
            'frontend/src/index.css'
        ]
        
        template_static_dir = self.template_dir / 'static'
        
        for static_file in static_files:
            src_path = template_static_dir / static_file
            dst_path = service_dir / static_file
            
            if src_path.exists():
                dst_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_path, dst_path)
                print(f"Copied static file: {dst_path}")
    
    def make_scripts_executable(self, service_dir):
        """Make shell scripts executable"""
        script_files = [
            'build.sh',
            'tag_push.sh',
            'install.sh'
        ]
        
        for script_file in script_files:
            script_path = service_dir / script_file
            if script_path.exists():
                script_path.chmod(0o755)
                print(f"Made executable: {script_path}")
    
    def generate_service(self, config):
        """Generate complete service from configuration"""
        self.validate_config(config)
        context = self.prepare_template_context(config)
        
        service_name = context['service_name_kebab']
        service_dir = self.output_dir / service_name
        
        # Create output directory
        service_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"Generating service: {service_name}")
        print(f"Output directory: {service_dir}")
        
        # Define template mappings
        template_files = [
            # Root files
            ('Dockerfile.j2', 'Dockerfile'),
            ('build.sh.j2', 'build.sh'),
            ('tag_push.sh.j2', 'tag_push.sh'),
            ('README.md.j2', 'README.md'),
            ('docker-compose.yml.j2', 'docker-compose.yml'),
            
            # Helm chart
            ('chart/Chart.yaml.j2', 'chart/Chart.yaml'),
            ('chart/values.yaml.j2', 'chart/values.yaml'),
            ('chart/templates/deployment.yaml.j2', 'chart/templates/deployment.yaml'),
            ('chart/templates/service.yaml.j2', 'chart/templates/service.yaml'),
            ('chart/templates/ingress.yaml.j2', 'chart/templates/ingress.yaml'),
            ('chart/templates/_helpers.tpl.j2', 'chart/templates/_helpers.tpl'),
        ]
        
        # Add backend-specific templates
        if context['has_backend']:
            backend_lang = context['backend_language']
            
            if backend_lang == 'python':
                template_files.extend([
                    ('backend/python/requirements.txt.j2', 'backend/requirements.txt'),
                    ('backend/python/run.py.j2', 'backend/run.py'),
                    ('backend/python/app/__init__.py.j2', 'backend/app/__init__.py'),
                    ('backend/python/app/config.py.j2', 'backend/app/config.py'),
                    ('backend/python/app/routes/__init__.py.j2', 'backend/app/routes/__init__.py'),
                    ('backend/python/app/routes/health.py.j2', 'backend/app/routes/health.py'),
                    ('backend/python/app/auth/middleware.py.j2', 'backend/app/auth/middleware.py'),
                ])
            elif backend_lang == 'nodejs':
                template_files.extend([
                    ('backend/nodejs/package.json.j2', 'backend/package.json'),
                    ('backend/nodejs/server.js.j2', 'backend/server.js'),
                    ('backend/nodejs/routes/health.js.j2', 'backend/routes/health.js'),
                ])
        
        # Add agent-controller pattern templates
        if context['is_agent_controller']:
            # Replace root Dockerfile with controller-specific one
            template_files.remove(('Dockerfile.j2', 'Dockerfile'))
            template_files.append(('controller/Dockerfile.j2', 'controller/Dockerfile'))
            
            # Controller templates
            if context['has_controller']:
                # Default to python for controller backend
                template_files.extend([
                    ('controller/python/requirements.txt.j2', 'controller/requirements.txt'),
                    ('controller/python/controller.py.j2', 'controller/controller.py'),
                ])
                
                # Controller frontend (default to reactjs)
                template_files.extend([
                    ('controller/frontend/reactjs/src/App.jsx.j2', 'controller/frontend/src/App.jsx'),
                    ('controller/frontend/reactjs/src/components/TaskMonitor.jsx.j2', 'controller/frontend/src/components/TaskMonitor.jsx'),
                    ('frontend/reactjs/package.json.j2', 'controller/frontend/package.json'),
                    ('frontend/reactjs/public/index.html.j2', 'controller/frontend/public/index.html'),
                    ('frontend/reactjs/src/index.jsx.j2', 'controller/frontend/src/index.jsx'),
                    ('frontend/reactjs/src/components/Header.jsx.j2', 'controller/frontend/src/components/Header.jsx'),
                ])
            
            # Agent templates
            if context['has_agent']:
                # Default to python for agent
                template_files.extend([
                    ('agent/python/requirements.txt.j2', 'agent/requirements.txt'),
                    ('agent/python/agent.py.j2', 'agent/agent.py'),
                    ('agent/Dockerfile.j2', 'agent/Dockerfile'),
                ])
        
        # Add frontend-specific templates for standalone services
        elif context['has_frontend']:
            frontend_lang = context['frontend_language']
            
            if frontend_lang == 'reactjs':
                template_files.extend([
                    ('frontend/reactjs/package.json.j2', 'frontend/package.json'),
                    ('frontend/reactjs/public/index.html.j2', 'frontend/public/index.html'),
                    ('frontend/reactjs/src/index.jsx.j2', 'frontend/src/index.jsx'),
                    ('frontend/reactjs/src/App.jsx.j2', 'frontend/src/App.jsx'),
                    ('frontend/reactjs/src/components/Header.jsx.j2', 'frontend/src/components/Header.jsx'),
                ])
            elif frontend_lang == 'vue':
                template_files.extend([
                    ('frontend/vue/package.json.j2', 'frontend/package.json'),
                    ('frontend/vue/vite.config.js.j2', 'frontend/vite.config.js'),
                    ('frontend/vue/index.html.j2', 'frontend/index.html'),
                    ('frontend/vue/src/main.js.j2', 'frontend/src/main.js'),
                    ('frontend/vue/src/App.vue.j2', 'frontend/src/App.vue'),
                ])
        
        # Generate all template files
        for template_file, output_file in template_files:
            template_path = Path(template_file)
            output_path = service_dir / output_file
            
            # Check if template exists
            if (self.template_dir / template_path).exists():
                self.generate_file_from_template(template_path, output_path, context)
            else:
                print(f"Warning: Template not found: {self.template_dir / template_path}")
        
        # Copy static files
        self.copy_static_files(service_dir, context)
        
        # Make scripts executable
        self.make_scripts_executable(service_dir)
        
        print(f"\\nService '{service_name}' generated successfully!")
        print(f"Location: {service_dir.absolute()}")
        
        return service_dir

def create_sample_config():
    """Create a sample configuration file"""
    sample_config = {
        'service': {
            'name': 'my-awesome-service',
            'description': 'A sample full-stack service',
            'version': '0.1.0',
            'port': 8080,
            'backend': {
                'language': 'python',
                'port': 8080
            },
            'frontend': {
                'language': 'reactjs'
            },
            'infrastructure': {
                'registry': 'registry.gokcloud.com',
                'namespace': 'my-awesome-service',
                'ingress_host': 'my-awesome-service.gokcloud.com',
                'enable_https': True,
                'enable_oauth': True,
                'oauth_issuer': 'https://keycloak.gokcloud.com/realms/GokDevelopers',
                'oauth_client_id': 'gok-developers-client'
            }
        }
    }
    
    with open('sample_service_config.yaml', 'w') as f:
        yaml.dump(sample_config, f, default_flow_style=False, indent=2)
    
    print("Sample configuration created: sample_service_config.yaml")

def main():
    parser = argparse.ArgumentParser(description='Generate a new service from template')
    parser.add_argument('--config', help='Service configuration YAML file')
    parser.add_argument('--service-name', help='Name of the service')
    parser.add_argument('--backend', choices=['python', 'nodejs'], help='Backend language')
    parser.add_argument('--frontend', choices=['reactjs', 'vue', 'angular'], help='Frontend language')
    parser.add_argument('--output-dir', default='generated_services', help='Output directory')
    parser.add_argument('--template-dir', default='templates', help='Template directory')
    parser.add_argument('--create-sample', action='store_true', help='Create a sample config file')
    
    args = parser.parse_args()
    
    if args.create_sample:
        create_sample_config()
        return
    
    generator = ServiceGenerator(template_dir=args.template_dir, output_dir=args.output_dir)
    
    # Load configuration
    if args.config:
        config = generator.load_config(args.config)
    elif args.service_name and args.backend:
        # Create config from command line arguments
        config = {
            'service': {
                'name': args.service_name,
                'backend': {'language': args.backend}
            }
        }
        
        if args.frontend:
            config['service']['frontend'] = {'language': args.frontend}
    else:
        parser.print_help()
        print("\\nError: Either --config file or --service-name and --backend are required")
        sys.exit(1)
    
    try:
        service_dir = generator.generate_service(config)
        
        print(f"\\nNext steps:")
        print(f"1. cd {service_dir}")
        print(f"2. Review and customize the generated files")
        print(f"3. Build: ./build.sh")
        print(f"4. Push: ./tag_push.sh") 
        print(f"5. Deploy: helm install {config['service']['name']} ./chart")
        
    except Exception as e:
        print(f"Error generating service: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()