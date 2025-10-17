#!/bin/bash

# Vault Guidance Module
# This file contains guidance functions specific to Vault installation and usage

# Show Vault next steps and recommend next component
show_vault_next_steps() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🚀 Vault Post-Installation Steps${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Immediate Next Steps:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Access Vault UI to verify cluster health and initialization${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Review and configure additional authentication methods${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  3. Set up policies and roles for applications${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  4. Configure secrets engines for different use cases${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  5. Test secret storage and retrieval operations${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  6. Set up backup and disaster recovery procedures${COLOR_RESET}"
  echo

  echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: Monitoring${COLOR_RESET}"
  echo -e "${COLOR_CYAN}Vault provides secrets management - now add monitoring for observability!${COLOR_RESET}"
  echo
  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install monitoring next?${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📊 Comprehensive metrics and logging collection${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🔍 Detailed insights into system and application performance${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🚨 Proactive alerting for issues and anomalies${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📈 Historical data analysis and trend monitoring${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🛠️  Troubleshooting support with detailed diagnostics${COLOR_RESET}"
  echo
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install monitoring now?${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install monitoring${COLOR_RESET}"
  echo

  # Suggest and install monitoring as the next step
  suggest_and_install_next_module "vault"
}

# Show detailed Vault configuration guidance
show_vault_configuration_guide() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}📋 Vault Configuration Guide${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Accessing Vault UI:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  URL: https://vault.${DOMAIN:-your-domain.com}${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Root Token: kubectl get secret vault-init-keys -n vault -o json | jq -r '.data[\"vault-init.json\"]' | base64 -d | jq -r '.root_token'${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Authentication Methods:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Kubernetes Auth: Already configured for service accounts${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • LDAP Auth: kubectl exec -n vault vault-0 -- vault auth enable ldap${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • UserPass Auth: kubectl exec -n vault vault-0 -- vault auth enable userpass${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • JWT/OIDC Auth: kubectl exec -n vault vault-0 -- vault auth enable oidc${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Secrets Engines:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • KV v2 (enabled): kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Database: kubectl exec -n vault vault-0 -- vault secrets enable database${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • AWS: kubectl exec -n vault vault-0 -- vault secrets enable aws${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • TLS Certificates: kubectl exec -n vault vault-0 -- vault secrets enable pki${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Creating Policies and Roles:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Create policy: vault policy write my-policy - << EOF${COLOR_RESET}"
  echo -e "${COLOR_CYAN}     path \"secret/*\" { capabilities = [\"read\"] }${COLOR_RESET}"
  echo -e "${COLOR_CYAN}     EOF${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Create role: vault write auth/kubernetes/role/my-role bound_service_account_names=my-service bound_service_account_namespaces=default policies=my-policy${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Using Vault with Applications:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Kubernetes Service Account: Automatic authentication${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • CSI Driver: Mount secrets as volumes${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Vault Agent: Sidecar injection for secrets${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • API Access: Direct HTTP calls with tokens${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Backup and Recovery:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Snapshot: vault operator raft snapshot save backup.snap${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Restore: vault operator raft snapshot restore backup.snap${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • DR Replication: vault write /sys/replication/dr/primary/enable${COLOR_RESET}"
}

# Show Vault troubleshooting guide
show_vault_troubleshooting() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔧 Vault Troubleshooting Guide${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Common Issues and Solutions:${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Vault pods not starting${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check storage: kubectl get pvc -n vault${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check logs: kubectl logs -n vault vault-0${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify storage class: kubectl get storageclass${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Vault is sealed${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check status: kubectl exec -n vault vault-0 -- vault status${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Unseal manually: kubectl exec -n vault vault-0 -- vault operator unseal${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check unseal keys: kubectl get secret vault-init-keys -n vault${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Cannot access Vault UI${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check ingress: kubectl get ingress -n vault${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify TLS certificate: kubectl describe certificate -n vault${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check service: kubectl get svc -n vault${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Authentication failures${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check auth methods: kubectl exec -n vault vault-0 -- vault auth list${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify policies: kubectl exec -n vault vault-0 -- vault policy list${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check service account: kubectl get serviceaccount -n <namespace>${COLOR_RESET}"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Issue: Secrets not accessible${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check secrets engines: kubectl exec -n vault vault-0 -- vault secrets list${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Verify permissions: kubectl exec -n vault vault-0 -- vault token capabilities <token> <path>${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check KV engine: kubectl exec -n vault vault-0 -- vault kv list secret${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Useful Commands:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Check status: kubectl exec -n vault vault-0 -- vault status${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • List secrets: kubectl exec -n vault vault-0 -- vault kv list secret${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • List policies: kubectl exec -n vault vault-0 -- vault policy list${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • View logs: kubectl logs -f -n vault vault-0${COLOR_RESET}"
}

# Show Vault security best practices
show_vault_security_guide() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔒 Vault Security Best Practices${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Access Control:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use principle of least privilege for policies${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Implement role-based access control (RBAC)${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Regularly rotate authentication tokens${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use short-lived credentials when possible${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Encryption:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Enable TLS for all communications${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use strong encryption for data at rest${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Implement proper key management${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Regularly rotate encryption keys${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Monitoring and Auditing:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Enable audit logging for all operations${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Monitor access patterns and anomalies${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Set up alerts for suspicious activities${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Regularly review audit logs${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Operational Security:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Keep Vault and dependencies updated${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Implement backup and recovery procedures${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Use multi-factor authentication where possible${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Implement network segmentation${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Disaster Recovery:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Maintain off-site backups of Vault data${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Test recovery procedures regularly${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Implement geo-redundancy if required${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  • Document emergency access procedures${COLOR_RESET}"
}

export -f show_vault_next_steps
export -f show_vault_configuration_guide
export -f show_vault_troubleshooting
export -f show_vault_security_guide