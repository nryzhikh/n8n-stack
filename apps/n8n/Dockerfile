# Custom n8n with Chrome Remote Interface support
FROM docker.n8n.io/n8nio/n8n

USER root

# Install packages globally so they're available to n8n Code nodes
RUN npm install -g puppeteer-core node-html-to-image cheerio string-similarity serpapi jimp

USER node

