Uses the Contentful Management API to get the published entries for the given
content types and then walks through the snapshots of each entry to look for
slugs that have changed from the first snapshot till the last.

Set up a .env with

```
CONTENTFUL_SPACE_ID=
CONTENTFUL_MANAGEMENT_TOKEN=
```

This is rough and still has things like content types and output file names hard-coded.
