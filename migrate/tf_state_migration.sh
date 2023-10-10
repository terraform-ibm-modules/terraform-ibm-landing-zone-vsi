#!/bin/bash

# fetch the list of security group names
group_list=$(terraform state list | grep 'ibm_is_security_group.security_group' | awk -F '["\\[]' '{print $3}')
echo "Security group list:"
echo "$group_list"

# fetch the list of security group rule names from terraform state
rule_list=$(terraform state list | grep 'ibm_is_security_group_rule.security_group_rules' | awk -F '["\\[]' '{print $3}')
echo "Security group rule list:"
echo "$rule_list"

n=1
# use terraform mv command to migrate the state
for group in $group_list; do
    echo "Moving $group state"
    terraform state mv "module.slz_vsi.ibm_is_security_group.security_group[\"$group\"]" "module.slz_vsi.module.security_groups[\"$group\"].ibm_is_security_group.sg[0]"
    # fetch nth line from rule_list
    rule=$(echo "$rule_list" | sed -n "$n"p)
    echo "Moving $rule state file"
    terraform state mv "module.slz_vsi.ibm_is_security_group_rule.security_group_rules[\"$rule\"]" "module.slz_vsi.module.security_groups[\"$group\"].ibm_is_security_group_rule.security_group_rule[0]"
    # increment n by 1
    n=$((n+1))
done

echo "State migration complete!"
