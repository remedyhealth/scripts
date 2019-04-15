require('dotenv-defaults').config()
const Contentpull = require('contentpull')
const fs = require('fs')

const dal = new Contentpull(
  process.env.CONTENTFUL_SPACEID,
  process.env.CONTENTFUL_APIKEY
)

dal._getAllObjects({
  content_type: 'redirect'
}).then(data => {
  const json = data.items.reduce((ret, entry) => {
    ret[entry.fields.url] = entry.fields.redirect
    return ret
  }, {})

  fs.writeFileSync('data.json', JSON.stringify(json, null, 2), 'utf8')
}).catch(err => {
  console.log(err)
})
