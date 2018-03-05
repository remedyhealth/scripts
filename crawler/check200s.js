const fs = require('fs')
const fetch = require('node-fetch')

const data = JSON.parse(fs.readFileSync(__dirname + '/all2.json', 'utf8'))

const page = 3
const limit = 100000
const startAt = 385510
const domain = 'http://beta.healthcentral.com'
const urls = data.urls.slice(startAt, startAt + limit)
const four04s = []

const logit = (status, url) => {
  if (status !== 200) {
    console.log(`${status}: ${url}`)
    four04s.push({
      status,
      url
    })
  }
}

const start = (i = 0) => {
  if (i < urls.length) {
    const url = urls[i]
    console.log(`${i} / ${urls.length} (${(i * 100 / urls.length).toFixed(2)}%)`)
    return fetch(`${domain}${url}`).then(res => {
      logit(res.status, url)
      return start(i + 1)
    }).catch((err) => {
      logit('000', url)
      return start(i + 1)
    })
  }

  return Promise.resolve()
}

const shutdown = (signal) => (err) => {
  console.log(`${signal}...`)
  if (err) console.error(err.stack || err)

  console.log(`404s: ${four04s.length}`)
  fs.writeFileSync(__dirname + '/' + (limit * (page + 1)) + '.csv', four04s.map(v => `${v.status},${v.url}`).join('\n'))

  process.exit(err ? 1 : 0)
}
process
  .on('SIGTERM', shutdown('SIGTERM'))
  .on('SIGINT', shutdown('SIGINT'))
  .on('uncaughtException', shutdown('uncaughtException'))

start().then(shutdown('finished'))
