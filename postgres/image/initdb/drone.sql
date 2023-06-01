create database drone;
create user drone with encrypted password 'drone';
grant all privileges on database drone to drone;
ALTER DATABASE drone OWNER TO drone;
