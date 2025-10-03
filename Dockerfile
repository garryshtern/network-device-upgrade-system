# Network Device Upgrade System - Production Container
# Optimized for RHEL8/9 podman compatibility with non-root execution
FROM python:3.13-alpine

# Metadata labels for GitHub Container Registry
LABEL org.opencontainers.image.title="Network Device Upgrade System"
LABEL org.opencontainers.image.description="Automated network device firmware upgrade system using Ansible. Supports Cisco NX-OS/IOS-XE, FortiOS, Opengear, and Metamako with comprehensive validation and rollback."
LABEL org.opencontainers.image.vendor="Network Operations"
LABEL org.opencontainers.image.version="1.4.0"
LABEL org.opencontainers.image.source="https://github.com/garryshtern/network-device-upgrade-system"
LABEL org.opencontainers.image.documentation="https://github.com/garryshtern/network-device-upgrade-system/tree/main/docs"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/garryshtern/network-device-upgrade-system"

# Install system dependencies required for Ansible and network operations
RUN apk add --no-cache \
    openssh-client \
    sshpass \
    git \
    curl \
    bash \
    sudo \
    tzdata \
    ca-certificates \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    cargo \
    rust \
    && rm -rf /var/cache/apk/*

# Create non-root user for security and RHEL/podman compatibility
RUN addgroup -g 1000 ansible \
    && adduser -D -u 1000 -G ansible -s /bin/bash ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible

# Create runtime directory with proper permissions for ansible user
RUN mkdir -p /var/lib/network-upgrade \
    && chown -R ansible:ansible /var/lib/network-upgrade \
    && chmod 755 /var/lib/network-upgrade

# Set working directory
WORKDIR /opt/network-upgrade

# Copy requirements first for better layer caching
COPY ansible-content/collections/requirements.yml ./ansible-content/collections/requirements.yml

# Install Ansible and Python dependencies as non-root user
USER ansible

# Set PATH to include user pip binaries
ENV PATH="/home/ansible/.local/bin:${PATH}"

# Upgrade pip and install Ansible with latest versions
RUN pip install --user --no-cache-dir --upgrade pip \
    && pip install --user --no-cache-dir \
        ansible \
        paramiko \
        netaddr \
        jinja2 \
        pyyaml \
        requests \
        psutil

# Install Ansible collections with explicit versions
RUN ansible-galaxy collection install \
    -r ansible-content/collections/requirements.yml \
    --collections-path ~/.ansible/collections \
    --force --ignore-certs

# Copy application content with proper ownership
COPY --chown=ansible:ansible ansible-content/ ./ansible-content/
COPY --chown=ansible:ansible tests/ ./tests/
COPY --chown=ansible:ansible docs/ ./docs/
COPY --chown=ansible:ansible deployment/ ./deployment/
COPY --chown=ansible:ansible CLAUDE.md ./CLAUDE.md
COPY --chown=ansible:ansible docker-entrypoint.sh ./docker-entrypoint.sh

# Make entrypoint executable
RUN chmod +x docker-entrypoint.sh

# Set Ansible environment variables
ENV ANSIBLE_CONFIG="/opt/network-upgrade/ansible-content/ansible.cfg"
ENV ANSIBLE_COLLECTIONS_PATH="/home/ansible/.ansible/collections"
ENV ANSIBLE_ROLES_PATH="/opt/network-upgrade/ansible-content/roles"

# Health check to verify Ansible installation (run as ansible user)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD su ansible -c "ansible --version && ansible-galaxy collection list"

# Switch back to root for container startup
# The entrypoint script will handle privilege drop to ansible user after SSH key setup
USER root

# Set entrypoint and default command
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["syntax-check"]

# Expose common ports for monitoring/metrics (optional)
EXPOSE 8080 9090