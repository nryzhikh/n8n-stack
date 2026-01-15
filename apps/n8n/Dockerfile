# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Set npm global prefix and install packages
RUN npm config set prefix /usr/local && \
    npm install -g \
    puppeteer-core \
    node-html-to-image \
    cheerio \
    string-similarity \
    serpapi \
    jimp

# Set NODE_PATH so n8n can find the packages
ENV NODE_PATH=/usr/local/lib/node_modules

USER node

