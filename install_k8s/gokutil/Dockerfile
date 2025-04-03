# Use a base image with LDAP tools
FROM debian:latest

# Install necessary tools
RUN apt-get update && apt-get install -y ldap-utils bash curl jq

# Set the default command to bash
CMD ["bash"]