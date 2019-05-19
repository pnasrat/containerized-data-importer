#!/usr/bin/env bash
set -e

function seed_images(){
  container=""
  container_alias=""
  images="${@:-${DOCKER_IMAGES}}"
  for arg in $images; do
      name=$(basename $arg)
      container="${container} registry:5000/${name}:latest"
  done

  # We don't need to seed the nodes, but in the case of the default dev setup we'll just leave this here
  for i in $(seq 1 ${KUBEVIRT_NUM_NODES}); do
      ./cluster-up/ssh.sh "node$(printf "%02d" ${i})" "echo \"${container}\" | xargs \-\-max-args=1 sudo docker pull"
      # Temporary until image is updated with provisioner that sets this field
      # This field is required by buildah tool
      ./cluster-up/ssh.sh "node$(printf "%02d" ${i})" "sudo sysctl \-w user.max_user_namespaces=1024"
  done

}

function verify() {
  echo 'Wait until all nodes are ready'
  until [[ $(_kubectl get nodes --no-headers | wc -l) -eq $(_kubectl get nodes --no-headers | grep " Ready" | wc -l) ]]; do
    sleep 1
  done
  echo "cluster node are ready!"
}

function configure_local_storage() {
  echo "Local storage already configured ..."
}

function install_cdi {
  _kubectl apply -f "./_out/manifests/release/cdi-operator.yaml"
}

function wait_cdi_crd_installed {
  timeout=$1
  crd_defined=0
  while [ $crd_defined -eq 0 ] && [ $timeout > 0 ]; do
      crd_defined=$(_kubectl get customresourcedefinition| grep cdis.cdi.kubevirt.io | wc -l)
      sleep 1
      timeout=timeout-1
  done

  #In case CDI crd is not defined after 120s - throw error
  if [ $timeout \< 1 ]; then
     echo "ERROR - CDI CRD is not defined after timeout"
     exit 1
  fi

}

