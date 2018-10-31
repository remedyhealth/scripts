/*
Simply `node .` works!
*/

const fetch = require('node-fetch')
const fs = require('fs')
const { JSDOM } = require('jsdom')
const errors = []

const request = async (url) => {
  const response = await fetch(url)
  return response
}

const getUrls = async (url) => {
  const response = await request(url)
  const text = await response.text()
  const { document } = new JSDOM(text).window
  return [].slice.call(document.querySelectorAll('loc')).map($el => $el.textContent.replace('https://www.healthcentral.com/', 'http://localhost:3000/'))
}

const testUrl = async (url) => {
  const response = await request(url)
  const text = await response.text()
  if (response.status !== 200) {
    throw {
      status: response.status
    }
  } else if (text.indexOf('Uh oh') !== -1) {
    throw {
      message: '5xxish reponse'
    }
  } else if (text.indexOf('Page not found') !== -1) {
    throw {
      message: '4xxish response'
    }
  }
}

const testUrls = async (urls) => {
  //const response = await request('https://www.healthcentral.com/index.xml')
  for (let i = 0; i < urls.length; i++) {
    console.log(`Testing (${i + 1}/${urls.length}): ${urls[i]}`)
    try {
      await testUrl(urls[i])
    } catch (err) {
      if (err.status) {
        console.log(`- Bad Status: ${err.status}`)
      } else if (err.message) {
        console.log(`- ${err.message}`)
      } else {
        console.log(err)
      }
      errors.push({
        url: urls[i],
        message: err.status || err.message || 'BAD'
      })
    }
  }
}

// taken from https://www.healthcentral.com
const sitemaps = [
  'https://www.healthcentral.com/quiz.xml',
  'https://www.healthcentral.com/author.xml',
  'https://www.healthcentral.com/article.xml',
  'https://www.healthcentral.com/encyclopedia.xml',
  'https://www.healthcentral.com/slideshow.xml',
  'https://www.healthcentral.com/category.xml',
  'https://www.healthcentral.com/sponsoredCollection.xml',
  'https://www.healthcentral.com/tag.xml',
  'https://www.healthcentral.com/placeholder.xml',
  'https://www.healthcentral.com/custom.xml'
]

const testSitemaps = async () => {
  for (let i = 0; i < sitemaps.length; i++) {
    console.log(`=== ${sitemaps[i]} ===`)
    try {
      const urls = await getUrls(sitemaps[i])
      await testUrls(urls)
    } catch (err) {
      console.log(err)
    }
  }
}

const run = async () => {
  await testSitemaps()
  fs.writeFileSync(__dirname + '/errors.json', JSON.stringify(errors, null, 2))
  console.log(`COMPLETE - ${errors.length} errors`)
}

run()
