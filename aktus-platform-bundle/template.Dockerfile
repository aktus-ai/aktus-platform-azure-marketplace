# syntax=docker/dockerfile-upstream:1.4.0
# This is a template Dockerfile for the bundle image
# You can customize it to use different base images, install tools and copy configuration files.
#
# Porter will use it as a template and append lines to it for the mixins
# and to set the CMD appropriately for the CNAB specification.
#
# Add the following line to porter.yaml to instruct Porter to use this template
# dockerfile: template.Dockerfile

# You can control where the mixin's Dockerfile lines are inserted into this file by moving the "# PORTER_*" tokens
# another location in this file. If you remove a token, its content is appended to the end of the Dockerfile.

FROM --platform=linux/amd64 ghcr.io/getporter/porter:v1.3.0

# This is a template Dockerfile for the bundle's invocation image
# You can customize it to use different base images, install tools and copy configuration files. 
# Porter will use it as a Dockerfile template.
# See https://porter.sh/bundle/custom-dockerfile/

# You can control where the mixin's Dockerfile lines are inserted into this file by moving "# PORTER_MIXINS" line
# another location in this file. If you remove that line, the mixins generated content is appended to this file.
# PORTER_MIXINS

# Use the BUNDLE_DIR build argument to copy files into the bundle
ARG BUNDLE_DIR

# Switch to root to install packages
USER root

# Install additional tools needed for Azure Marketplace and Kubernetes
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then KUBECTL_ARCH="amd64"; elif [ "$ARCH" = "arm64" ]; then KUBECTL_ARCH="arm64"; else KUBECTL_ARCH="amd64"; fi && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KUBECTL_ARCH}/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install -y helm \
    && rm -rf /var/lib/apt/lists/*

# Switch back to nonroot user
USER nonroot

# Copy the bundle files
COPY --chown=nonroot:nonroot . ${BUNDLE_DIR}
