const fetch = require('node-fetch')
const diffchecker = require('diffchecker/dist/transmit').default

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

  // this opens your browser every time...
  diffchecker({
    left: html.beta.split('beta.healthcentral.com').join('www.healthcentral.com'),
    right: html.prod
  })
  return true
}

const data = [
  '/about',
  // '/',
  // '/amp/article/the-nappers-advantage-lower-blood-pressure',
  // '/amp/encyclopedia/acidophilus',
  // '/article/the-nappers-advantage-lower-blood-pressure',
  // '/author/diane-domina',
  // '/category/adhd',
  // '/category/healthy-living/tag/medication',
  // '/collection/living-chronic-hives',
  // '/category/chronic-hives/tag/self-care',
  // '/custom/body-mass-index-calculator',
  // '/encyclopedia',
  // '/encyclopedia/acidophilus',
  // '/exit/bridging-the-gap-living-with-chronic-hives',
  // '/launch/bridging-the-gap-living-with-chronic-hives',
  // '/newsletter',
  // '/newsletter/thank-you',
  // '/quiz/what-do-you-know-about-adult-adhd',
  // '/slideshow/10-tips-newly-diagnosed-adult-adhd',
  // '/category/healthy-living/tag/medication',
  // '/video/michael-kuluva-raises-awareness-through-fashion',
  // '/all-authors',
  // '/conditions',
  // '/search?q=test',
  // '/category/adhd'
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
