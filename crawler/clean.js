const fs = require('fs')

const dataDir = __dirname + '/data'
const allData = {}

fs.readdirSync(dataDir).forEach(file => {
  const data = JSON.parse(fs.readFileSync(dataDir + '/' + file, 'utf8'))
  let allUpdated = 0

  Object.keys(data).forEach(url => {
    // if (allData[url]) {
    //   console.error(url, 'ALREADY EXISTS:', file, ' from', allData[url])
    //   process.exit(1)
    // } else {
    //   allData[url] = file
    // }

    let updated = 0

    delete data[url]
    url = url.toLowerCase().replace('//', '/')

    if (url[0] !== '/') {
      url = "/" + url
      updated++
      // console.error(`URL does not start with "/" ${url}`)
    }

    if (url[url.length - 1] === '/') {
      updated++
      url = url.substring(0, url.length - 1)
    }

    data[url] = true
    if (updated) {
      allUpdated++
    }
    // SAVE
  })

  console.log(`Updated ${allUpdated} from "${file}"`)
  fs.writeFileSync(__dirname + '/clean-data/' + file, JSON.stringify(data, null, 2))
})

console.log(`Completed all ${Object.keys(allData).length} records.`)
