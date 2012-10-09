monexp
======

Reusable webapp parts for Express with MongoDB.

Usage:

```coffeescript

express = require 'express'
mongolian = require 'mongolian'

app = express.createServer()

server = new mongolian
db = server.db "mrblisted"

# The users module
monexp.users.init app, db

```


