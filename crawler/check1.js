// const fs = require('fs')
//
// const dataDir = __dirname + '/data'
// const allData = {}
//
// fs.readdirSync(dataDir).forEach(file => {
//   const data = JSON.parse(fs.readFileSync(dataDir + '/' + file, 'utf8'))
//   let allUpdated = 0
//
//   Object.keys(data).forEach(url => {
//     if (allData[url]) {
//       console.error(url, 'ALREADY EXISTS:', file, ' from', allData[url])
//       process.exit(1)
//     } else {
//       allData[url] = file
//     }
//   })
// })
//
// console.log(`Completed all ${Object.keys(allData).length} records.`)
// fs.writeFileSync(__dirname + '/all.json', JSON.stringify(allData, null, 2))

const fs = require('fs')
const fetch = require('node-fetch')
const csv = require('fast-csv')
const data = Object.keys(JSON.parse(fs.readFileSync(__dirname + '/all.json', 'utf8')))
const domain = 'http://www.healthcentral.com'

// const urls = Object.keys(data)
// console.log(urls[urls.length - 1])

const nonMigrated = []
const four04 = []

fs.createReadStream('data.csv').pipe(csv()
  .on('data', (data) => {
    let url = data[1]
      .trim()
      .toLowerCase()
      .replace('http://www.healthcentral.com', '')
      .replace('http://healthcentral.com', '')
      .replace('www.healthcentral.com', '')

    if (url[0] !== '/') {
      url = '/' + url
    }

    if (url[url.length - 1] === '/') {
      url = url.substring(0, url.length - 1)
    }

    console.log(`Checking: ${url}`)
    if (data.indexOf(url) === -1) {
      nonMigrated.push(url)
    } else {
      // return fetch(domain + url).then(res => {
      //   if (res.status !== 200) {
      //     four04.push(url)
      //   }
      // })
    }

  })
  .on('end', () => {
    // console.log(`404s: ${four04.length}`)
    // four04.forEach(v => {
    //   console.log(`- ${v}`)
    // })

    console.log(`non-migrated: ${nonMigrated.length}`)
    nonMigrated.forEach(v => {
      console.log(`- ${v}`)
    })
    // const filename = 'all.json'
    // fs.writeFileSync(filename, JSON.stringify(j, null, 2))
    // console.log(`Wrote ${Object.keys(j).length} entries to "${filename}"`)
  })
)

// console.log('Total')

// fetch('http://healthcentral.com/').then(res => {
//   console.log(`fetch: ${res.status}`)
// })
