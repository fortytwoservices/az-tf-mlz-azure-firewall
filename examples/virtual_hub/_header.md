# Virtual WAN hub example

A Virtual WAN with one virtual hub, and a Standard firewall in the hub (a secured hub) with a policy the
module creates, a rule collection group, and the hub's routing intent sending Internet and private
traffic through the firewall.

Run it with `scripts/e2e.sh examples/virtual_hub`: apply, a second plan that must be empty, destroy. The
virtual hub takes 20 to 30 minutes to create and to delete, and the hub and the firewall cost by the hour
while they exist.
