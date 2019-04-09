const contentful = require('contentful-management')
const Promise = require('bluebird')
const fs = require('fs')
const csv = require('fast-csv')
const _ = require('lodash')
require('dotenv').config()

const client = contentful.createClient({
  accessToken: process.env.CONTENTFUL_MANAGEMENT_TOKEN
})

const csvStream = csv.format({headers: true})
const writeableStream = fs.createWriteStream('test.csv')
writeableStream.on("finish", () => {
  console.log("Done writing csv!")
})
csvStream.pipe(writeableStream)

const pageLimit = 1000

function pagedGet (space, query = {}, skip = 0, aggregatedResponse = null) {
  return space.getEntries(Object.assign(query, {
    skip: skip,
    limit: pageLimit,
    order: 'sys.createdAt'
  }))
  .then((response) => {
    if (!aggregatedResponse) {
      aggregatedResponse = response
    } else {
      aggregatedResponse.items = aggregatedResponse.items.concat(response.items)
    }
    if (skip + pageLimit <= response.total) {
      return pagedGet(space, query, skip + pageLimit, aggregatedResponse)
    }
    return aggregatedResponse
  })
}

const getAllIds = async (contentType) => {
  const space = await client.getSpace(process.env.CONTENTFUL_SPACE_ID)
  const entries = await pagedGet(space, {
    content_type: contentType,
    select: 'sys.id,sys.publishedVersion,fields.slug',
    'sys.publishedVersion[exists]':true
  })
  // console.log('entry ids', entries.items)
  // console.log(entries.items[0])
  console.log(`${contentType} entries [${entries.items.length}]`)
  return entries
}

const getChangedSlugs = (entry) => {
  // console.log(entry)
  return client.rawRequest({
    method: 'GET',
    url: `${process.env.CONTENTFUL_SPACE_ID}/entries/${entry.sys.id}/snapshots`
  })
  .then((data) => {
    // console.log(data)
    if (data.items.length < 2) {
      return null
    }

    console.log(`${entry.sys.id} has ${data.items.length} snapshots`)
    const first = data.items[0].snapshot.fields.slug['en-US']
    const last = data.items[data.items.length - 1].snapshot.fields.slug['en-US']
    // console.log(first, last)

    if (first !== last) {
      csvStream.write({
        id: entry.sys.id,
        originalSlug: last,
        currentSlug: first
      })
    }

    return {
      id: entry.sys.id,
      originalSlug: last,
      currentSlug: first
    }
  })
  .catch((err) => {
    console.log(err)
  })
}

const processEntries = (entries) => {
  const promise = Promise.map(entries, entry => {
    return getChangedSlugs(entry)
  }, { concurrency: 2 })
  .then(entries => entries.filter(entry => entry))

  return promise
}

const writeChangedSlugsToCSV = (entries) => {
  // const changedSlugs = entries.filter(entry => entry.originalSlug !== entry.currentSlug)
  // console.log(changedSlugs)
  // console.log(`Changed count [${changedSlugs.length}]`)

  csvStream.end()

}

Promise.map(['article'], contentType => {
    return getAllIds(contentType)
  }, { concurrency: 1 })
  .then(entries => {
    const temp = entries.reduce((foo, entry) => {
      const temp = [...foo, ...entry.items]
      return temp
    }, [])
    return temp
  })
  .then(processEntries)
  .then(writeChangedSlugsToCSV)
