name        "postgresql"
description "PostgreSQL Server Support"

run_list(
	"recipe[apt]",
	"recipe[ssh_deploy_keys]",
	"recipe[postgresql::repository]", 
	"recipe[postgresql::access]", 
	"recipe[postgresql::client_install]", 
	"recipe[postgresql::server_install]",
	"recipe[apt::unattended-upgrades]",
	"recipe[postgresql::backup_dir]"
	)    