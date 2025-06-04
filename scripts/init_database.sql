/*
=============================
Creating Databases(MySQl)
=============================
Script Purpose:
  This script creates new databases(Schemas) for each layer(Bronze, Silver, Gold) after checking if they already exists.
  If the database already exists, it is dropped and recreated.
Warning:
  Running this script will drop the entire 'Bronze, Silver, Gold' Databases if it exists.
  All data in them will be lost, so go ahead with caution.
-----------------------------
Script:
*/
  
-- drop databases if already exists
drop database if exists Bronze;
drop database if exists Silver;
drop database if exists Gold;

-- recreate the databases(schemas)
create database Bronze;
create database Silver;
create database Gold;
