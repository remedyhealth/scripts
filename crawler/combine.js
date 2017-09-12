const fs = require('fs')

const dataDir = __dirname + '/clean-data'
const allData = {}

fs.readdirSync(dataDir).forEach(file => {
  const data = JSON.parse(fs.readFileSync(dataDir + '/' + file, 'utf8'))
  let allUpdated = 0

  Object.keys(data).forEach(url => {
    if (allData[url]) {
      console.error(url, 'ALREADY EXISTS:', file, ' from', allData[url])
      process.exit(1)
    } else {
      allData[url] = file
    }
  })
})

console.log(`Completed all ${Object.keys(allData).length} records.`)
fs.writeFileSync(__dirname + '/all.json', JSON.stringify(allData, null, 2))
