# Multiple Nodes

A node is a machine running a [node agent](../agent/README.md) and, under it,
an inference server. The control plane keeps a list of them and drives each
over HTTP.

---

## Adding one

Two ends have to agree.

On the machine, in its `config.xml`:

```xml
<node>
  <bind>0.0.0.0</bind>
  <agent_port>15972</agent_port>
  <node_token>a-shared-secret</node_token>
</node>
```

In `control.xml`:

```xml
<nodes>
  <node id="local" name="local"      url="http://127.0.0.1:15972" token=""/>
  <node id="gpu2"  name="GPU node 2" url="http://10.0.0.12:15972" token="a-shared-secret"/>
</nodes>
```

| Attribute | Meaning |
|---|---|
| `id` | Internal identifier, used in API calls |
| `name` | What the UI shows |
| `url` | That machine's agent |
| `token` | Must equal that machine's `<node_token>` |

`<bind>` must be an address the control plane can reach. `127.0.0.1` — the
default — accepts only local connections, which is correct for a
single-machine install and wrong the moment control lives elsewhere.

## What is shared, what is not

This is the part that surprises people.

| Shared across nodes | Per node |
|---|---|
| Accounts, tokens, sessions (one database) | Models, and the disks they live on |
| Logic graphs, if they are on the same server | `config.xml`, including every model entry |
| | GPUs and the placement decided from them |

Each machine has its **own** model list. Adding a model on one node does not
add it anywhere else; the same alias on two nodes may point at different files
and different quantizations.

A graph's AI config names a model by alias. Run that graph against a server
whose machine lacks the alias and it fails — the Logic Editor console flags it
as "references models the server does not have".

Keeping aliases consistent across machines is a convention you have to
maintain; nothing enforces it.

## Which server does a client talk to?

Directly, and only to one: `cage.server.host` and `.port` in the editor.
Control is not a proxy and is not in that path.

So distributing work across machines means pointing editors at different
servers. There is no automatic scheduling across nodes.

## Practical layouts

**One machine.** Control, agent and server on one box; agent on `127.0.0.1`;
node list has one entry. Nothing else needed.

**A few GPU machines, one admin.** Control on whichever box is always up —
possibly one with no GPU. Each GPU machine runs an agent bound to a reachable
address with a token. One database, shared by control and every server.

**Separating heavy models.** A machine with big cards holds the large models; a
smaller one holds fast utility models. Point graphs that need each at the
matching server. Common aliases with different backing quantizations per
machine is a reasonable pattern — a graph then runs on either.

## Health

`/node/status` per node gives process state, uptime, health, VRAM and loaded
models — this is what the dashboard shows.

An unreachable node means control cannot reach that agent. The inference server
on that machine may be perfectly fine and its clients unaffected; those are
independent paths.

---

[← Control Plane](README.md) · [Accounts](accounts.md) · [Server Guide](../README.md)
