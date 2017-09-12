const fs = require('fs')
const fetch = require('node-fetch')

const four04s = []

const data = JSON.parse(fs.readFileSync(__dirname + '/all-organized.json', 'utf8'))

const page = 1
const limit = 500000
const domain = 'http://localhost:3002'
const urls = data.urls.slice((page - 1) * limit, limit * page)

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
  fs.writeFileSync(__dirname + '/badurls' + page + '.csv', four04s.map(v => `${v.status},${v.url}`).join('\n'))

  process.exit(err ? 1 : 0)
}

process
  .on('SIGTERM', shutdown('SIGTERM'))
  .on('SIGINT', shutdown('SIGINT'))
  .on('uncaughtException', shutdown('uncaughtException'))

start().then(shutdown('finished'))
