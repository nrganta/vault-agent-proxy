# This script is to be run by a Vault admin to get Vault ready.
#!/bin/bash
# export VAULT_ADDR=http://127.0.0.1:8201
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_NAMESPACE=admin

mkdir -p -m755 /home/nag/vault-agent-proxy/vault-data/
mkdir -p -m755 /home/nag/vault-agent-proxy/logs/
export LOG_FILE=/home/nag/vault-agent-proxy/logs/vault.log

nohup vault server -dev -dev-root-token-id root > $LOG_FILE 2>&1 &

# Grab the vault root token from file
while IFS= read -r line || [[ -n "$line" ]]; do
    export VAULT_TOKEN=$line
done < vault_root_token.txt
# Create an approle
vault auth enable approle
# Create a policies one for the vault agent used with the app
vault policy write agent agent-policy.hcl
# Create a tightly restricted policy to only allow writing of wrapped tokens
vault policy write restart-agent restart-agent-policy.hcl
# Create an approle role for the vault agent
vault write auth/approle/role/agent \
    secret_id_ttl=2h \
    token_num_uses=100 \
    token_ttl=5h \
    token_max_ttl=24h \
    secret_id_num_uses=150 \
    token_policies="agent"
# Create an approle role for the when the vault agent restarts
vault write -force auth/approle/role/restart-agent \
    secret_id_num_uses=0 \
    token_policies="restart-agent"

# Create a KV secret
vault kv put secret/test foo=bar
vault kv put secret/devgrid db_name="dev1" password="myPassword"
vault kv put secret/lngrid  db_name="lndev1" password="myPassword"

# Read the role_id and create a wrapped secret_id and store them in the proper location for the vault agent
vault read -field=role_id auth/approle/role/agent/role-id > ./webblog_role_id
# Uncomment below to use secret_id directly
# vault write -field=secret_id -f auth/approle/role/agent/secret-id > ./webblog_wrapped_secret_id
# Uncomment below to use the wrapped secret_id
vault write -field=wrapping_token -wrap-ttl=200s -f auth/approle/role/agent/secret-id > ./webblog_wrapped_secret_id
# Create a role-id and secret-id that doesn't expire with a tight policy scope to only write wrapped secret-ids
vault read -field=role_id auth/approle/role/restart-agent/role-id > ./restart_role_id
vault write -field=secret_id -f auth/approle/role/restart-agent/secret-id > ./restart_secret_id
