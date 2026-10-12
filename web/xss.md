# XSS checks

Locate reflection: HTML text, attribute, script, DOM sink.

```text
< > ' " { } ;
```
```xml
<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>
```
- Compare raw response vs rendered DOM; `&lt;` is text, not execution.
- SVG: only in a browser-rendered context; verify in the actual display context.
- Stored = saved for later visitors; reflected = in response to crafted request; DOM = browser source → sink.
