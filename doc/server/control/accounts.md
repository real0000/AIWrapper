# Accounts

Who can use the server, and who can administer it. Both live in the same
database; the control plane is where they are managed.

---

## Two kinds

| Kind | Used for | Stored |
|---|---|---|
| Admin | Signing in to the control plane web UI | `admin_users` |
| User | Connecting an editor to the inference server | `users`, with tokens in `api_keys` |

Passwords are hashed with PBKDF2-HMAC-SHA256. Nothing stores a plaintext
password except the bootstrap entry in `control.xml`, which is why that file is
mode 600.

## The bootstrap account

```xml
<admin>
  <username>admin</username>
  <password>a-real-password</password>
</admin>
```

It does two jobs:

- **First run.** When the admin table is empty and this password is non-empty,
  this account is created. After that, manage accounts in the UI — the file is
  not read again for that purpose.
- **Fallback.** If the database is unreachable, this pair is accepted as a
  single account so you can still reach the UI and diagnose the problem.

**An empty password disables authentication.** The UI opens to anyone who can
reach the port, with full control of every node. That is a deliberate option for
a laptop install; it is not one for anything else.

## User accounts and tokens

Users are created in the UI. Each can hold personal access tokens.

A client authenticates with either:

- a **session token** from `AIWrapper: Login` — the normal path, managed by the
  extension; or
- a **personal access token** pasted into `aiwrapper.server.apiKey` — for
  scripted or headless clients.

Tokens are sent as a bearer on every request, which is the reason TLS matters
on anything beyond localhost: without it, every request carries a reusable
credential in the clear.

## Per-user accounting

With a database, sessions and token usage are recorded per user, so
consumption is attributable. Logic graphs are owned: private to their creator
unless shared, in which case they appear in everyone's selector on that server.

## Running without a database

Perfectly viable for one person:

```
[warning] MySQL connect failed (Connection refused) — DB features disabled
[info] [auth] auth DISABLED (dev-open) (users=0, masterKey=no)
```

The server then accepts every request without authentication. There are no
accounts, no per-user history, and no usage accounting. Chat history still
works — the client keeps its own.

`<api_key>` in `config.xml` is the middle ground: one shared static token, no
database, but not open either.

## Checklist for a shared deployment

1. Same database in `config.xml` and `control.xml`.
2. Schema loaded: `mysql -u root -p < sql/schema.sql`.
3. A real bootstrap password, then create individual accounts in the UI.
4. TLS on the inference server — tokens travel on every request.
5. `node_token` set on every agent.
6. Control plane bound to localhost or behind a TLS proxy.

---

[← Control Plane](README.md) · [Multiple nodes](nodes.md) · [Server Guide](../README.md)
