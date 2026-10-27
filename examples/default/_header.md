# Default example

A hub virtual network with an `AzureFirewallSubnet`, a Log Analytics workspace, and a Standard firewall
with its public IP address and a policy the module creates: DNS proxy on, one IP group for the spokes,
and a rule collection group with a network rule (DNS from the spokes) and an application rule (Windows
Update). The firewall's logs go to the workspace.

Run it with `scripts/e2e.sh examples/default`: apply, a second plan that must be empty, destroy. A
Standard firewall costs by the hour while it exists, and creating or deleting one takes several minutes.
