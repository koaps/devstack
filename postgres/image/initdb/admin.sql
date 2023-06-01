create user admin with encrypted password 'adm1n';
grant usage, create on schema public to admin;
grant all privileges on database drone to admin;
grant all privileges on database gogs to admin;
