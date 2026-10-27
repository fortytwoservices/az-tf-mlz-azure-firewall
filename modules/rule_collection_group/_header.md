# Rule collection group

One rule collection group (`Microsoft.Network/firewallPolicies/ruleCollectionGroups`) on a firewall
policy: application, network and DNAT rule collections, each a map keyed by its name, with its rules
keyed by theirs, so adding an entry never shifts the others. A collection holds one rule type only, which
the three maps enforce. The root module creates the groups in its `rule_collection_groups` input; a
separate rules state can call this submodule on its own with the policy ID, so a rule change never plans
the firewall.

Writes are serialised on the policy (`locks`), because Azure refuses parallel writes of rule collection
groups to one policy (`AnotherOperationInProgress`), which the default `retry` also covers. IP groups are
referenced by resource ID.
