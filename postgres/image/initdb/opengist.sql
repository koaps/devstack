create database opengist;
create user opengist with encrypted password 'opengist';
grant all privileges on database opengist to opengist;
ALTER DATABASE opengist OWNER TO opengist;
