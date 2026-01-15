# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Install custom packages to a separate directory
WORKDIR /opt/custom-nodes
RUN npm init -y && npm install \
    chrome-remote-interface \
    puppeteer-core \
    node-html-to-image \
    cheerio \
    string-similarity \
    googlethis@latest \
    serpapi \
    jimp

# Make packages available to n8n task runner
ENV NODE_PATH=/opt/custom-nodes/node_modules

USER node

