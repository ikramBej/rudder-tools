###############################
# Setup ncf for a local usage #
###############################
get_cfengine_url() {
  VERSION="$1"
  ARCH=$(arch)
  if [ "${PM}" = "apt" ]
  then
    DEBARCH=$(dpkg --print-architecture)
    echo "https://cfengine-package-repos.s3.amazonaws.com/community_binaries/Community-${VERSION}/agent_deb_${ARCH}/cfengine-community_${VERSION}-1_${DEBARCH}-debian4.deb"
  elif [ "${PM}" = "yum" ] || [ "${PM}" = "zypper" ]
  then
    ARCH=$(arch)
    echo "https://cfengine-package-repos.s3.amazonaws.com/community_binaries/Community-${VERSION}/agent_rpm_${ARCH}/cfengine-community-${VERSION}-1.el4.${ARCH}.rpm"
  fi
}

setup_ncf() {

  # install dependencies
  install_test_dependencies

  # setup cfengine

  # cfengine from ci
  if echo "${CFENGINE_VERSION}" | grep "rudder" >/dev/null
  then
    # cfengine from Rudder
    RUDDER_VERSION=$(echo "${CFENGINE_VERSION}" | cut -f2- -d "-")
    add_repo
    setup_agent || true # To allow failing inventories, when we have no server
    remove_repo
    ln -nsf /var/rudder/cfengine-community /var/cfengine
  else
    # cfengine vanilla
    url=$(get_cfengine_url "${CFENGINE_VERSION}")
    file=$(mktemp)
    get "${file}" "${url}"
    ${PM_LOCAL_INSTALL} "${file}"
  fi

  # setup ncf
  if echo "${NCF_VERSION}" | grep "^[0-9.\\-]*$" > /dev/null
  then
    # TODO ncf package from repo
    echo "pure ncf packaging not ready yet"
  elif echo "${NCF_VERSION}" | grep "^rudder" > /dev/null
  then
    if [ "${COMMAND}" = "test-local" ]
    then
      echo "tests requires using a git repository as ncf source"
      exit 1
    fi

    # ncf package from Rudder
    RUDDER_VERSION=$(echo "${NCF_VERSION}" | cut -f 2 -d "-")
    add_repo
    ${PM_INSTALL} ncf
    remove_repo
  else
    directory=$(mktemp -d)

    ## NCF from local source
    if [ -d "${NCF_VERSION}" ]
    then
      echo "Installing ncf from local source: ${NCF_SOURCE}" 
      cp -r ${NCF_VERSION}/* ${directory}
    ## NCF from git
    else
      git_url=$(echo "${NCF_VERSION}" | cut -f 1 -d "#")
      git_branch=$(echo "${NCF_VERSION}" | cut -f 2 -d "#")
      [ -z "${git_branch}" ] && git_branch=master
      git clone -q -b "${git_branch}" "${git_url}" "${directory}"
    fi

    cd "${directory}"
    # avoid making doc
    mkdir -p doc && touch doc/ncf.1
    # Old branches do not have an "install" target
    if grep -q "install:" Makefile; then 
      make install
    fi
  fi

  # setup ncf within cfengine
  rm -rf /var/cfengine/inputs/*
  if [ -d /usr/share/ncf/tree/ ]; then
    cp -r /usr/share/ncf/tree/* /var/cfengine/inputs/
  fi
}

checkout_pr() {
  cd "${directory}"
  git fetch origin pull/$PULL_REQUEST/head:local_pr
  git checkout local_pr
}
