create database vault;
create user vault with encrypted password 'vault';
grant all privileges on database vault to vault;
ALTER DATABASE vault OWNER TO vault;
