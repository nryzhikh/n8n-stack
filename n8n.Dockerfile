# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n:latest

USER root

# Install chrome-remote-interface for CDP communication
RUN cd /usr/local/lib/node_modules/n8n && \
    npm install chrome-remote-interface puppeteer-core

USER node

