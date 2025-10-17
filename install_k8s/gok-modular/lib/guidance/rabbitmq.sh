#!/bin/bash

# RabbitMQ Guidance Module
# This file contains guidance functions specific to RabbitMQ installation and usage

# Show RabbitMQ next steps and recommend next component
show_rabbitmq_next_steps() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🚀 RabbitMQ Post-Installation Steps${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Immediate Next Steps:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Access RabbitMQ Management UI to verify cluster health${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Create additional users and virtual hosts for applications${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  3. Configure message TTL and queue policies${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  4. Set up monitoring and alerting for queue depths${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  5. Test message publishing/consuming with sample applications${COLOR_RESET}"
  echo

  echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: Jenkins${COLOR_RESET}"
  echo -e "${COLOR_CYAN}RabbitMQ provides messaging - now add Jenkins for CI/CD automation!${COLOR_RESET}"
  echo
  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install Jenkins next?${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🔄 Automated build, test, and deployment pipelines${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📦 Artifact management and version control integration${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🤖 Extensive plugin ecosystem for diverse tooling${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📊 Comprehensive monitoring and reporting capabilities${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🚀 Scalable architecture for growing development teams${COLOR_RESET}"
  echo
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install Jenkins now?${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install jenkins${COLOR_RESET}"
  echo

  # Suggest and install Jenkins as the next step
  suggest_and_install_next_module "rabbitmq"
}

# Show detailed RabbitMQ configuration guidance
show_rabbitmq_configuration_guide() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}📋 RabbitMQ Configuration Guide${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Accessing RabbitMQ Management UI:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  URL: https://rabbitmq.${DOMAIN:-your-domain.com}${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Username: Use the credentials extracted during installation${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Command: kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.username}' | base64 --decode${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Command: kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.password}' | base64 --decode${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Creating Virtual Hosts:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Log into Management UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Go to Admin → Virtual Hosts${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  3. Add virtual host (e.g., /myapp)${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  4. Set permissions for users${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}User Management:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Go to Admin → Users in Management UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Add new users with appropriate tags${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  3. Set permissions for virtual hosts${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  4. Use tags: management, policymaker, monitoring, administrator${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Queue and Exchange Configuration:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use durable queues for persistent messages${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure dead letter exchanges for failed messages${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set message TTL policies for automatic cleanup${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use topic exchanges for flexible routing${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Monitoring and Alerting:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor queue lengths and consumer counts${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set up alerts for unacked messages${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Track connection and channel usage${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor node memory and disk usage${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}High Availability Best Practices:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use mirrored queues across all cluster nodes${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure proper resource limits${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set up proper backup and recovery procedures${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor cluster partition handling${COLOR_RESET}"
}

# Show RabbitMQ troubleshooting guide
show_rabbitmq_troubleshooting() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔧 RabbitMQ Troubleshooting Guide${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Common Issues and Solutions:${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: RabbitMQ pods not starting${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check persistent volume claims: kubectl get pvc -n rabbitmq${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify storage class availability: kubectl get storageclass${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check pod logs: kubectl logs -n rabbitmq <pod-name>${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Cannot access Management UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify ingress configuration: kubectl get ingress -n rabbitmq${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check ingress controller status${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify DNS resolution for rabbitmq domain${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Authentication failures${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify credentials: kubectl get secret rabbitmq-default-user -n rabbitmq${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check user permissions in Management UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Ensure virtual host permissions are set${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Messages not being consumed${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check queue bindings and routing keys${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify consumer connections in Management UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check for dead letter queues${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Cluster not forming properly${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check cluster status: kubectl get rabbitmqcluster -n rabbitmq${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify all pods are running: kubectl get pods -n rabbitmq${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check cluster operator logs: kubectl logs -n rabbitmq-system deployment/rabbitmq-cluster-operator${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Useful Commands:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check cluster status: kubectl exec -it -n rabbitmq <pod-name> -- rabbitmqctl cluster_status${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • List queues: kubectl exec -it -n rabbitmq <pod-name> -- rabbitmqctl list_queues${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • List connections: kubectl exec -it -n rabbitmq <pod-name> -- rabbitmqctl list_connections${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • View logs: kubectl logs -f -n rabbitmq <pod-name>${COLOR_RESET}"
}

# Show RabbitMQ performance tuning tips
show_rabbitmq_performance_tips() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}⚡ RabbitMQ Performance Tuning${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Memory Optimization:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set vm_memory_high_watermark to 0.6 (60%)${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure vm_memory_high_watermark_paging_ratio${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor memory usage in Management UI${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Disk I/O Optimization:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use fast storage for persistent messages${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set disk_free_limit appropriately${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor disk space usage${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Network Optimization:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use TCP_NODELAY for low latency${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure heartbeat intervals${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use appropriate frame_max settings${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Queue Optimization:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use lazy queues for large message backlogs${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure queue max length limits${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set appropriate message TTL${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Connection Management:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Reuse connections and channels when possible${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Configure connection_max${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor connection churn${COLOR_RESET}"
}

export -f show_rabbitmq_next_steps
export -f show_rabbitmq_configuration_guide
export -f show_rabbitmq_troubleshooting
export -f show_rabbitmq_performance_tips