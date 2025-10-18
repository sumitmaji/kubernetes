reset_gok_controller(){
  # Uninstall Gok Controller using Helm
  helm uninstall gok-controller -n gok-controller

  # Delete the Gok Controller namespace
  kubectl delete ns gok-controller
}
export -f reset_gok_controller