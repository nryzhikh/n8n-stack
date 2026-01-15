# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Install packages in n8n's node_modules so task runner can find them
WORKDIR /usr/local/lib/node_modules/n8n
RUN npm install --save \
    chrome-remote-interface \
    puppeteer-core \
    node-html-to-image \
    cheerio \
    string-similarity \
    googlethis@latest \
    serpapi \
    jimp

# Also set NODE_PATH as fallback
ENV NODE_PATH=/usr/local/lib/node_modules/n8n/node_modules

WORKDIR /home/node
USER node

