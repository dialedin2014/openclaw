FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server \
      openssh-client && \
    if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES; \
    fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Setup SSH for the container
RUN mkdir -p /run/sshd /home/node/.ssh && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "AllowUsers node" >> /etc/ssh/sshd_config && \
    chmod 700 /home/node/.ssh && \
    chown -R node:node /home/node/.ssh

# Create startup script that runs SSH daemon and keeps container running
RUN printf '#!/bin/bash\nset -e\n/usr/sbin/sshd -D &\nsleep infinity\n' > /app/start.sh && \
    chmod +x /app/start.sh

# Create gateway startup script that runs SSH daemon and gateway
RUN printf '#!/bin/bash\nset -e\n/usr/sbin/sshd\nexec node /app/dist/index.js "$@"\n' > /app/start-gateway.sh && \
    chmod +x /app/start-gateway.sh

# Create openclaw CLI wrapper for exec tool
RUN printf '#!/bin/sh\nexec node /app/dist/index.js "$@"\n' > /usr/local/bin/openclaw && \
    chmod +x /usr/local/bin/openclaw

ENTRYPOINT ["/app/start.sh"]
CMD []
