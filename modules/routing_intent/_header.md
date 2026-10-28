# Routing intent

The routing intent of a Virtual WAN hub (`Microsoft.Network/virtualHubs/routingIntent`): which traffic the
hub sends to a next hop, usually the hub's Azure Firewall. Each routing policy is keyed by its name and
takes one destination, `Internet` or `PrivateTraffic`: a hub has at most one policy of each kind.
`replace_triggers` replaces the routing intent together with its next hop. The root module creates it for a firewall in a
virtual hub (`virtual_hub.routing_intent`); it can also be called on its own with the hub's ID and a next
hop.

Writes are serialised on the hub (`locks`), because Azure refuses parallel writes to one hub's children
(`AnotherOperationInProgress`), which the default `retry` also covers. A hub has one routing intent.
