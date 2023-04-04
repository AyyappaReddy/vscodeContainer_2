# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.163.1/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
ARG VARIANT="focal"
# Note that the base image is mirrored to RB DTR to prevent proxy issues pulling from Jenkins worker
# FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}
FROM localhost.com/user/vscode-devcontainer-base:0-${VARIANT} AS base

# Add CA Certs
COPY .devcontainer/*.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Tweak proxy for case sudo is demanded inside docker
# Check internet access to fail fast
COPY .devcontainer/connect_test.sh /tmp/
RUN echo "Defaults  env_keep += \"http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY\"" >> /etc/sudoers && \
    timeout -k 5 5 /tmp/connect_test.sh

# Set the docker user to the user of the environment preventing file system owner mismatch
ARG UID=0
ARG GID=0
ARG USER=vscode
RUN if [ "${USER}" != "vscode" -a "${UID}" != "1000" ]; then \
    groupadd -g ${GID} ${USER} && \
    useradd -l -m -u ${UID} -g ${GID} ${USER}; \
    fi && \
    mkdir /home/${USER}/.cache && chown ${USER}:${USER} /home/${USER}/.cache && \
    mkdir /home/${USER}/.conan && chown ${USER}:${USER} /home/${USER}/.conan && \
    echo $USER ALL=\(root\) NOPASSWD:/usr/bin/apt-get > /etc/sudoers.d/$USER && \
    echo $USER ALL=\(root\) NOPASSWD:/usr/bin/dpkg >> /etc/sudoers.d/$USER && \
    cp /root/.bashrc /home/${USER}/.bashrc && chown ${USER}:${USER} /home/${USER}/.bashrc

# Definition of a base CPP Development incl ROS container with reduced volumlocalhost.come and complexity
FROM base AS cpp-dev
USER root

# Re-propagate ARG-value in new build stage
# See: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
ARG VARIANT
ARG RB_ARTIFACTORY_USER="xxxxxx"
ARG RB_ARTIFACTORY_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Use local Mirrors located at BCN
# Note: Pipeline-Depth option is required because  mirrors seem to not conform to HTTP/1.1 specification for HTTP pipelining.
# This causes issues on high-latency connections (e.g. connected via VPN).
# Also see https://github.com/delphix/appliance-build/issues/146#issuecomment-561249725 and https://manpages.debian.org/stretch/apt/apt.conf.5.en.html
RUN echo "deb http://mirror-localhost.com/ubuntu $(lsb_release -sc) main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirror-localhost.com/ubuntu $(lsb_release -sc)-security main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirror-localhost.com/ubuntu $(lsb_release -sc)-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-od-mirror-fixes && \
    echo 'Acquire::http::Pipeline-Depth "0";' >> /etc/apt/apt.conf.d/80-od-mirror-fixes

# Use local PIP-Mirrors located at BCN
# HOTFIX for stability issues of PIP mirror / PMTDT-2671 / Disable temporarily
#RUN echo "[global]" > /etc/pip.conf && \
#    echo "index-url = https://${RB_ARTIFACTORY_USER}:${RB_ARTIFACTORY_KEY}@rb-artifactory.bosch.com/artifactory/api/pypi/python-virtual/simple" >> /etc/pip.conf && \
#    echo "index = https://${RB_ARTIFACTORY_USER}:${RB_ARTIFACTORY_KEY}@rb-artifactory.bosch.com/artifactory/api/pypi/python-virtual/" >> /etc/pip.conf

COPY .devcontainer/install_deb_set.sh \
    requirements-deb-cpp.txt \
    tools/packaging/third-party/packages/${VARIANT}/carla_client_*_amd64.deb \
    tools/packaging/third-party/packages/${VARIANT}/geographic_transform_*_amd64.deb \
    tools/packaging/third-party/packages/${VARIANT}/include-what-you-use_*_amd64.deb \
    tools/packaging/third-party/packages/${VARIANT}/lanelet2_*_amd64.deb \
    tools/packaging/simulation_core_deps/build-simulation-core-lib-deps-aarch64.sh /tmp/
RUN timeout -k 5 5 /tmp/connect_test.sh http://mirror-localhost.com/ubuntu && \
    if [ $(cat /tmp/*.deb|wc -c) -lt 20480 ]; then echo Enable GIT LFS before Docker build; exit 7; fi && \
    /tmp/install_deb_set.sh /tmp/requirements-deb-cpp.txt && \
    bash /tmp/build-simulation-core-lib-deps-aarch64.sh /usr/aarch64-linux-gnu && \
    rm -rf /tmp/requirements-deb-cpp.txt /tmp/*.deb /tmp/build-simulation-core-lib-deps-aarch64.sh
ENV PATH="/usr/lib/ccache:$PATH"
USER ${USER}

# Definition of the default Development container including CPP dev and PIP dev dependencies
FROM cpp-dev AS without-venv
ARG VARIANT
USER root

# Install external and internal (from the repo) Python dependencies
COPY requirements-deb-pip.txt requirements-pip.txt /tmp/
COPY tools/jiri tools/jiri
RUN timeout -k 5 5 /tmp/connect_test.sh && \
    /tmp/install_deb_set.sh /tmp/requirements-deb-pip.txt && \
    python3 -m pip install --upgrade pip 'setuptools==65.5.0' wheel && \
    python3 -m pip install -r /tmp/requirements-pip.txt --ignore-installed && \
    rm -rf /tmp/requirements-deb-pip.txt /tmp/requirements-pip.txt /root/.cache

# Install debian dependencies
COPY requirements-deb.txt \
    tools/packaging/third-party/packages/${VARIANT}/fossid-cli-tools-*.amd64.deb /tmp/
RUN timeout -k 5 5 /tmp/connect_test.sh && \
    /tmp/install_deb_set.sh /tmp/requirements-deb.txt && \
    rm -rf /tmp/requirements-deb.txt /tmp/fossid-cli-tools-*.amd64.deb && \
    echo "[CLI]" >/etc/fossid.conf && \
    echo "cli_server_host = rb-fossid.de.bosch.com" >>/etc/fossid.conf && \
    echo "cli_token = ffffffffff" >>/etc/fossid.conf

# Install Helmfile and Helm plugins
RUN tmp_dir=$(mktemp -d) && \
    wget https://github.com/roboll/helmfile/releases/download/v0.144.0/helmfile_linux_amd64 -O "/usr/local/bin/helmfile" && \
    chmod +x "/usr/local/bin/helmfile" && \
    helm plugin install https://github.com/databus23/helm-diff && \
    helm plugin install https://github.com/jkroepke/helm-secrets && \
    helm plugin install https://github.com/mumoshu/helm-x && \
    wget https://github.com/variantdev/vals/releases/download/v0.16.2/vals_0.16.2_linux_amd64.tar.gz -O "${tmp_dir}/vals.tar.gz" && \
    tar -xf "${tmp_dir}/vals.tar.gz" --directory "${tmp_dir}" && \
    mv "${tmp_dir}/vals" "/usr/local/bin" && \
    wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.4/kustomize_v4.5.4_linux_amd64.tar.gz -O "${tmp_dir}/kustomize.tar.gz" && \
    tar -xf "${tmp_dir}/kustomize.tar.gz" --directory "${tmp_dir}" && \
    mv "${tmp_dir}/kustomize" "/usr/local/bin" && \
    rm -rf "${tmp_dir}"

# Prepare the container for Sphinx build:
#    Install plantuml manually -> the debian version is not up to date
#    Fix font permissions -> some required extensions do simply not work
RUN mkdir -p /opt/plantuml && \
    wget https://netcologne.dl.sourceforge.net/project/plantuml/plantuml.jar -O /opt/plantuml/plantuml.jar && \
    chmod 755 /opt/plantuml/plantuml.jar && \
    chmod 755 /usr/local/share/fonts && \
    luaotfload-tool -v -vvv -u

# Prepare the container for yase integration:
#    Install antlr-4 manually -> the debian version is not up to date
RUN timeout -k 5 5 /tmp/connect_test.sh && \
    mkdir -p /opt/antlr/lib && mkdir -p /opt/antlr/bin && \
    curl -Ls https://www.antlr.org/download/antlr-4.9.2-complete.jar -o /opt/antlr/lib/antlr-4.9.2-complete.jar && \
    printf '#!/bin/bash\njava -jar /opt/antlr/lib/antlr-4.9.2-complete.jar "$@"' > /opt/antlr/bin/antlr4.sh && \
    chmod 755 /opt/antlr/bin/antlr4.sh

USER ${USER}

# Definition of the default Docker devcontainer for most developers
FROM without-venv as default
# Definition of the Docker devcontainer including common virtual envs for effective development
FROM default AS venv

# Setup virtual environments (need to bring in some files as "fake" as GIT not available during build)
# Order of venvs is based on assumed volatility to maximize chaches and minimize re-build needs
COPY --chown=${USER} tools/venv/generic_create_venv.sh /workspaces/digital-testing/tools/venv/

# Definition of the Docker devcontainer with multiple ros versions available for DT Launcher system tests
FROM venv as ros
USER root


# Run ros install script
RUN --mount=type=secret,id=artifactory_user,mode=0444 \
    --mount=type=secret,id=artifactory_rb_apitoken,mode=0444 \
    --mount=type=secret,id=artifactory_bdc_apitoken,mode=0444 \
    /tmp/install_multiple_ros.sh "$(cat /run/secrets/artifactory_user)" "$(cat /run/secrets/artifactory_rb_apitoken)" "$(cat /run/secrets/artifactory_bdc_apitoken)"

USER ${USER}

FROM ros as cicd
