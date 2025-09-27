# Spring Boot Backend Service

This project is a Spring Boot application that serves as a backend service using an H2 database. It includes functionality for managing employees and departments, as well as integrating a Quartz job for scheduled tasks.

## Project Structure

```
springboot-backend-service
├── src
│   ├── main
│   │   ├── java
│   │   │   └── com
│   │   │       └── example
│   │   │           └── springbootbackend
│   │   │               ├── SpringbootBackendServiceApplication.java
│   │   │               ├── config
│   │   │               │   └── QuartzConfig.java
│   │   │               ├── controller
│   │   │               │   ├── DepartmentController.java
│   │   │               │   └── EmployeeController.java
│   │   │               ├── entity
│   │   │               │   ├── Department.java
│   │   │               │   └── Employee.java
│   │   │               ├── repository
│   │   │               │   ├── DepartmentRepository.java
│   │   │               │   └── EmployeeRepository.java
│   │   │               └── service
│   │   │                   ├── QuartzJobService.java
│   │   │                   └── EmployeeService.java
│   │   └── resources
│   │       ├── application.properties
│   │       └── data.sql
├── pom.xml
└── README.md
```

## Features

- **Employee Management**: Create, read, update, and delete employee records.
- **Department Management**: Create, read, update, and delete department records.
- **Quartz Scheduler**: Scheduled tasks using Quartz for background processing.

## Setup Instructions

1. **Clone the Repository**:
   ```
   git clone <repository-url>
   cd springboot-backend-service
   ```

2. **Build the Project**:
   Use Maven to build the project:
   ```
   mvn clean install
   ```

3. **Run the Application**:
   Start the Spring Boot application:
   ```
   mvn spring-boot:run
   ```

4. **Access the Application**:
   The application will be available at `http://localhost:8080`.

## Database Initialization

The H2 database will be initialized with sample data for employees and departments using the `data.sql` file located in `src/main/resources`.

## Dependencies

This project uses the following dependencies:
- Spring Boot
- H2 Database
- Quartz Scheduler

## License

This project is licensed under the MIT License.