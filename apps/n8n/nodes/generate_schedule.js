const CDP = require('chrome-remote-interface');

const fixtures = $json.matches;
const today = new Date().toISOString().split('T')[0];
const todayMatches = fixtures.filter((m) => m.utcDate.startsWith(today));

if (todayMatches.length === 0) {
  return { json: { html: `<p>No matches scheduled for today.</p>` } };
}

// Group by league
const grouped = todayMatches.reduce((acc, match) => {
  const league = match.competition.name;
  acc[league] = acc[league] || [];
  acc[league].push(match);
  return acc;
}, {});

const leagueSections = Object.entries(grouped)
  .map(([leagueName, matches]) => {
    const leagueLogo = matches[0]?.competition?.emblem || '';
    const rows = matches
      .map((match) => {
        const time = new Date(match.utcDate).toLocaleTimeString('en-GB', {
          hour: '2-digit',
          minute: '2-digit',
          timeZone: 'Europe/Moscow',
        });
        return `
          <tr>
            <td style="text-align:right; width:40%; color:#eee;">
              ${match.homeTeam.shortName || match.homeTeam.name}
              <img src="${match.homeTeam.crest}" width="32" height="32" style="vertical-align:middle; margin-left:8px;">
            </td>
            <td style="text-align:center; color:#ccc; font-size:24px; width:15%;">
              ${time}
            </td>
            <td style="text-align:left; width:40%; color:#eee;">
              <img src="${match.awayTeam.crest}" width="32" height="32" style="vertical-align:middle; margin-right:8px;">
              ${match.awayTeam.shortName || match.awayTeam.name}
            </td>
          </tr>`;
      })
      .join('');

    return `
      <div style="margin:14px 0;">
        <table>${rows}</table>
      </div>`;
  })
  .join('');


const nowMoscow = new Date().toLocaleString('ru-RU', {
  timeZone: 'Europe/Moscow',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
});

const html = `
<html>
<head>
  <meta charset="UTF-8">
  <style>
    html, body {
      background: #000;
      color: #eee;
      margin: 0;
      padding: 10px;
      font-family: 'Arial', sans-serif;
      overflow: hidden;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: #121212;
      font-size: 20px;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 6px rgba(255,255,255,0.08);
    }
    td {
      padding: 8px 10px;
      border-bottom: 1px solid #222;
      vertical-align: middle;
    }
    tr:last-child td {
      border-bottom: none;
    }
    .footer {
      margin-top: 10px;
      font-size: 20px;
      text-align: center;
    }
  </style>
</head>
<body>
<div class="footer"">
    ${nowMoscow}  ( мск )
  </div>
${leagueSections}
</body>
</html>`;

try {
  const targetInfo = await CDP.New({ host: 'chrome', port: 9222, url: 'about:blank' });
  const client = await CDP({ host: 'chrome', port: 9222, target: targetInfo.id });
  const { Page, Emulation } = client;

  await Page.enable();
  await Page.navigate({ url: 'data:text/html,' + encodeURIComponent(html) });
  await Page.loadEventFired();

  // Resize viewport to fit content (no scrollbar)
  const metrics = await Page.getLayoutMetrics();
  const height = Math.ceil(metrics.contentSize.height);
  await Emulation.setDeviceMetricsOverride({
    width: 800,
    height,
    deviceScaleFactor: 2.5,
    mobile: false,
  });

  const screenshot = await Page.captureScreenshot({ format: 'png' });
  await client.close();

  return {
    binary: {
      data: {
        mimeType: 'image/png',
        fileExtension: 'png',
        fileName: `matches-dark-${today}.png`,
        data: Buffer.from(screenshot.data, 'base64').toString('base64'),
      },
    },
    json: {
      matchCount: todayMatches.length,
      leagueCount: Object.keys(grouped).length,
      theme: 'dark',
      generatedAt: new Date().toISOString(),
    },
  };
} catch (error) {
  return { json: { error: error.toString() } };
}
