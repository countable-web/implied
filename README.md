monexp
======

Reusable webapp parts for Express with MongoDB.

Usage:

```javascript

express = require 'express'
mongolian = require 'mongolian'

app = express.createServer()

server = new mongolian
db = server.db "mrblisted"

# The users module
require('monexp').users.init app, db

```
