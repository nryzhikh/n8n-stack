# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Install packages using pnpm in n8n's directory
WORKDIR /usr/local/lib/node_modules/n8n
RUN pnpm add \
    chrome-remote-interface \
    puppeteer-core \
    node-html-to-image \
    cheerio \
    string-similarity \
    googlethis@latest \
    serpapi \
    jimp

USER node

