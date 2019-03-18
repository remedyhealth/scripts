const fetch = require('node-fetch')
const HtmlDiffer = require('html-differ').HtmlDiffer
const logger = require('html-differ/lib/logger')
const fs = require('fs')
const htmlDiffer = new HtmlDiffer({})

const request = async (path) => {
  const res = await fetch(path)
  if (res.status !== 200) {
    throw new Error(`Status was a "${res.status}"`)
  }
  const text = await res.text()
  return text
}

const getHTML = async (path) => {
  const beta = await request(`https://beta.healthcentral.com${path}`)
  const prod = await request(`https://www.healthcentral.com${path}`)
  return {
    beta: beta.split('beta.healthcentral.com').join('www.healthcentral.com'),
    prod
  }
}

const evaluate = async (path) => {
  const html = await getHTML(path)
  // const diff = htmlDiffer.diffHtml(html.prod, html.beta)
  const isEqual = htmlDiffer.isEqual(html.prod, html.beta)

  if (isEqual) {
    console.log(`- Equal`)
  } else {
    console.log(`- NOT EQUAL`)
  }
  console.log('')
  // logger.logDiffText(diff)
  // fs.writeFileSync(__dirname + `/${path.split('/').join('-')}.html`, `<style>.red { color: red; } .green { color: green; }</style><ul>${text}</ul>`)
  return true
}

const data = [
  '/about',
  '/amp/article/the-nappers-advantage-lower-blood-pressure',
  '/amp/encyclopedia/acidophilus',
  '/article/the-nappers-advantage-lower-blood-pressure',
  '/author/diane-domina',
  '/category/adhd',
  '/category/healthy-living/tag/medication',
  '/collection/living-chronic-hives',
  '/category/chronic-hives/tag/self-care',
  '/custom/body-mass-index-calculator',
  '/encyclopedia',
  '/encyclopedia/acidophilus',
  '/exit/bridging-the-gap-living-with-chronic-hives',
  '/launch/bridging-the-gap-living-with-chronic-hives',
  '/newsletter',
  '/newsletter/thank-you',
  '/quiz/what-do-you-know-about-adult-adhd',
  '/slideshow/10-tips-newly-diagnosed-adult-adhd',
  '/category/healthy-living/tag/medication',
  '/video/michael-kuluva-raises-awareness-through-fashion',
  '/all-authors',
  '/conditions',
  '/search?q=test',
  '/category/adhd'
]

const run = async () => {
  for (let i = 0; i < data.length; i++) {
    try {
      console.log(`Evaluating: ${data[i]}`)
      await evaluate(data[i])
    } catch (err) {
      console.log('ERROR:', err)
    }
  }

  console.log('complete!')
}

run()
