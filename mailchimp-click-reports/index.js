require('dotenv-defaults').config()
const fetch = require('node-fetch')
const base64 = require('base-64')
const fs = require('fs')

const actualRequest = async (url, key) => {
  const domain = `https://${process.env.DC}.api.mailchimp.com/3.0`
  const auth = base64.encode(`blahblah:${process.env.API_KEY}`)
  const response = await fetch(`${domain}${url}`, {
    credentials: 'include',
    headers: {
      'Authorization': `Basic ${auth}`
    }
  }).then(res => res.json())

  return key ? response[key] : response
}

const mcRequest = async (url, key, all) => {
  if (!all) {
    const response = await actualRequest(url, key)
    return response
  } else {
    const perPage = 10
    let total = 1
    let curPage = 0
    const all = []
    while (perPage * curPage < total) {
    // while (curPage < 2) {
      const response = await actualRequest(`${url}&offset=${perPage * curPage}`)
      curPage++
      total = response.total_items
      const value = response[key] || []
      all.push(...value)
      console.log('curPage', curPage)
      console.log('total_items', total)
      // console.log('`${url}&offset=${perPage * curPage}`', `${url}&offset=${perPage * curPage}`)
      // console.log('reponse', response)
      // process.exit()
    }

    return all
  }
}

const run = async () => {
  // const reports = await mcRequest('/reports?fields=reports.id,total_items', 'reports', true)
  const data = []
  const CAMPAIGNS = process.env.CAMPAIGNS.split(',')

  for (let i = 0; i < CAMPAIGNS.length; i++) {
    const report = CAMPAIGNS[i]
    const clickDetails = await mcRequest(`/reports/${report}/click-details?fields=urls_clicked,total_items`, 'urls_clicked', true)

    if (Array.isArray(clickDetails) && clickDetails.length > 0) {
      if (data.length === 0) {
        data.push(Object.keys(clickDetails[0]).join(','))
      }

      clickDetails.forEach(urlClicked => {
        delete urlClicked._links
        // process.exit()

        const values = Object.values(urlClicked)
        data.push(values.join(','))
      })
    }
  }

  fs.writeFileSync(__dirname + '/nidhika.csv', data.join('\n'), 'utf8')
}

run()
