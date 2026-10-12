# Insecure deserialization

| Stack | Clue |
| --- | --- |
| Java | Base64 `rO0AB…` or bytes `ac ed 00 05` |
| .NET | `__VIEWSTATE`, BinaryFormatter, LosFormatter, Json.NET; signing + `machineKey` |
| PHP | `unserialize()` on your input + `__wakeup()` / `__destruct()` |
| Python | `pickle.loads()` on your input |

- ViewState: a leaked `web.config` machine key undermines protection.
- Compare baseline vs one harmless change; parser errors ≠ execution.
