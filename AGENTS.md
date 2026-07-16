# Project automation rules

## Tour de France YouTube highlights updater

- Use the configured YouTube RSS sources first.
- If all configured RSS sources fail because of HTTP errors, timeouts, or other fetch errors, the updater may automatically fall back to scraping the configured YouTube playlist HTML page.
- HTML scraping is a supported fallback for this project because YouTube RSS feeds are frequently unreliable.
- Do not scrape unrelated YouTube pages or use a browser plugin for this fallback; use the existing updater implementation.
- Treat a successful HTML fallback as a completed updater attempt. Continue with the stage-results update, validation, commit, push, and deployment checks under the normal daily workflow.
- Report which RSS URLs failed and why, and explicitly state when HTML scraping was used and whether it found new highlight links.
- Apply the 30-minute RSS retry policy only when both RSS and the HTML fallback fail. Stop after the 07:00 Europe/Bucharest attempt as usual.
- After pushing a daily update, run `scripts/Test-ProductionDeployment.ps1` and report deployment success only when production contains the same latest completed stage and update date as the local data.
