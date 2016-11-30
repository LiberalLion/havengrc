# Mappa Mundi
[![CircleCI](https://circleci.com/gh/kindlyops/mappamundi.svg?style=svg)](https://circleci.com/gh/kindlyops/mappamundi)
[![experimental](http://badges.github.io/stability-badges/dist/experimental.svg)](http://github.com/badges/stability-badges)

The Controls Mapping service for Compliance Ops.

This exposes a data model using [PostgREST](http://postgrest.com/).

## run the service

The db schema and migrations are managed using sqitch.
The postgresql server, the postgrest API server, and the sqitch tool
are all run from docker containers to reduce the need for
local toolchain installation (perl, haskell, postgresql)

To check and see if you have docker available and set up

    docker -v
    docker-compose -v
    docker info

If you don't have docker running, use the instructions at https://docs.docker.com/docker-for-mac/.
At the time of writing, this is working fine with docker 1.12.

Once you have docker set up:

    docker-compose run --entrypoint="psql -h db -U postgres -c 'CREATE DATABASE mappamundi_dev'" sqitch
    docker-compose run sqitch deploy
    docker-compose up
    curl -s http://localhost:3000/ | jq

## add a database migration

    docker-compose run sqitch add foo -n "Add the foo table"

Edit deploy/foo.sql

```SQL
BEGIN;

CREATE TABLE mappa.foo
(
  name text NOT NULL PRIMARY KEY
);

COMMIT;
```

Edit revert/foo.sql

```SQL
BEGIN;

DROP TABLE mappa.foo CASCADE;

COMMIT;
```

    docker-compose run sqitch deploy # applies changes
    docker-compose run sqitch revert # reverts changes
    # repeat until satisfied
    git add .
    git commit -m "Adding foo table"

## look around inside the database

The psql client is installed in the sqitch image, and can connect
to the DB server running in the database image.

    docker-compose run --entrypoint="psql -h db -U postgres" sqitch
    \l                          # list databases in this server
    \connect mappamundi_dev     # connect to a database
    \dn                         # show the schemas
    \dt                         # show the tables
    SELECT * from foo LIMIT 1;  # run arbitrary queries
    \q                          # disconnect

## Use REST client to interact with the API

[Postman](https://www.getpostman.com/) is a free GUI REST client that makes exploration easy. Run postman, and import a couple of predefined requests
from the collection at postman/ComplianceOps.postman_collection.json.
Then execute the POST and GET requests to see how the API behaves.

## More info on postgrest

A tutorial is available here. http://blog.jonharrington.org/postgrest-introduction/

## Authentication with JWT and Auth0

Set JWT_SECRET in your environment from the 'Client Secret' in the Compliance Ops Auth0 admin page. This is the shared secret that is used to verify the JWT signature. JWTs are signed/hashed but not encrypted, so don't put confidential attributes in the JWT.

For the Auth0 user that you want to work with, set a read-only claim on the user in app_metadata, something like { "role" : "admin" }.
The role value must link up with the role defined inside postgrest.

There is a script in contrib that shows how to get a JWT from Auth0. You can then specify this JWT string in an Authorization: Bearer 'JWT'
header in Postman or in curl.

Note that we are currently running into https://github.com/begriffs/postgrest/issues/495 with the client secret that is provided by Auth0.
