import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'

const templateUrl = new URL('./site.caddy.template', import.meta.url)

test('keeps mutable responses no-store without overriding owned media caching', async () => {
  const template = await readFile(templateUrl, 'utf8')

  assert.match(template, /@noStore\s*\{\s*not path \/api_agent\/v2\/assets\/\*\/content \/api_agent\/v2\/assets\/\*\/poster \/api_agent\/v2\/assets\/\*\/thumbnail\s*\}/u)
  assert.match(template, /header @noStore Cache-Control "no-store"/u)
  assert.doesNotMatch(template, /header\s*\{[^}]*Cache-Control "no-store"/su)
  assert.match(template, /handle \/api_agent\/\*/u)
})
