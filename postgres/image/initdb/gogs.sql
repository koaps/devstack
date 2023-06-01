create database gogs;
create user gogs with encrypted password 'gogs';
grant all privileges on database gogs to gogs;
ALTER DATABASE gogs OWNER TO gogs;
