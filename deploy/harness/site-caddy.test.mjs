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

test('exposes only signed single-image reference reads before browser authentication', async () => {
  const template = await readFile(templateUrl, 'utf8')
  const block = template.split('# BEGIN POPI MODEL REFERENCES')[1].split('# END POPI MODEL REFERENCES')[0]
  assert.match(block, /method GET HEAD/u)
  assert.match(block, /path_regexp popi_model_reference \^\/api_agent\/v2\/media-references\//u)
  assert.match(block, /\[0-9a-f\]\{64\}\$/u)
  assert.match(block, /header_up -Authorization/u)
  assert.match(block, /header_up -Cookie/u)
  assert.doesNotMatch(block, /assets\/.*content|file_server|root \*/u)
  assert.ok(template.indexOf('# BEGIN POPI MODEL REFERENCES') < template.indexOf('forward_auth'))
  const origin = await readFile(new URL('./server.mjs', import.meta.url), 'utf8')
  assert.match(origin, /providerReferenceOrigin: publicOrigin\.origin/u)
})
