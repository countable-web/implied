
path = require 'path'
express = require 'express'

session = require('express-session')

module.exports = (app)->

  if not app.get "upload_dir"
    app.set "upload_dir", path.join "/var", app.get "app_name"
  
  app.set "view engine", "jade"
  
  if (app.get 'env') is 'development'
    app.locals.pretty = true
    app.locals.development = true
    
  #app.use express.limit '300mb'
  app.use express.bodyParser({upload_dir: '/tmp'})
  
  # Use helmet?
  if app.get('security_headers') is true
    helmet = require 'helmet'
    app.use(helmet.xframe())
    app.use(helmet.iexss())
    app.use(helmet.contentTypeOptions())
    app.use(helmet.cacheControl())
  
  app.use express.cookieParser()
  
  app.set 'session_enabled', (app.get 'session_enabled') or true
  app.set 'session_db_name', (app.get 'session_db_name') or 'session'
  app.set 'session_storage', (app.get 'session_storage') or 'mongodb'

  if app.get('session_enabled') is true

    # Sessions storage using FileStore
    if app.get('session_storage') is 'filestore'
      FileStore = require('session-file-store')(session)
      store = new FileStore(session)

    # Session storage using MongoDB
    else if app.get('session_storage') is 'mongodb'
      unless app.get('db_name')
        console.log 'ERROR: mongodb session storage requires a valid db_name set in the app configs'
      else
        MongoDBStore = require('connect-mongodb-session')(session)
        store_params = {
          uri: 'mongodb://' + app.get('db_name'),
          collection: app.get('session_db_name')
        }
        store = new MongoDBStore(store_params)

    # Invalid session storage
    else
      console.log 'ERROR: Invalid session_storage:', app.get 'session_storage'

    if store
      app.use session
        secret: (app.get 'secret') or "UNSECURE-STRING",
        store: store
      console.log 'Sessions are stored using', app.get 'session_storage'

  if app.get('csrf') is true
    app.use(express.csrf())
    app.use (req, res, next) ->
      res.locals.csrf = req.session._csrf
      next()
    
  app.use express.methodOverride()

  app.use (req, res, next)->
    if req.query.referrer
      req.session.referrer = req.query.referrer
    next()

  app.use express.static path.join app.get('dir'), 'public'
  app.use express.static app.get "upload_dir"

  app.locals.process = process

  # Middleware to make request available to templates.
  app.use (req,res,next)->
    res.locals.req = res.locals.request = req
    next()
