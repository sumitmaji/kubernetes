# ---- Build frontend ----
FROM node:20 AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
ENV NODE_OPTIONS=--openssl-legacy-provider
COPY frontend/ ./
RUN npm run build

# ---- Build backend ----
FROM python:3.11 AS backend-build
WORKDIR /app/backend
COPY backend/requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY backend/ ./

# ---- Final image ----
FROM python:3.11-slim
WORKDIR /app

# Copy backend code
COPY --from=backend-build /app/backend /app/backend

# Copy frontend build into backend's static directory
COPY --from=frontend-build /app/frontend/build /app/backend/static

# Install runtime dependencies
COPY backend/requirements.txt /app/backend/
RUN pip install --upgrade pip && pip install -r backend/requirements.txt

# Expose Flask port
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Start Flask app
CMD ["python", "backend/app.py"]