create database gitea;
create user gitea with encrypted password 'gitea';
grant all privileges on database gitea to gitea;
ALTER DATABASE gitea OWNER TO gitea;
