# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Install packages globally so they're available to n8n Code nodes
RUN npm install -g chrome-remote-interface puppeteer-core node-html-to-image cheerio string-similarity googlethis@latest serpapi jimp

# Set NODE_PATH so n8n Code nodes can find globally installed packages
ENV NODE_PATH=/usr/local/lib/node_modules:/opt/nodejs/lib/node_modules

USER node

