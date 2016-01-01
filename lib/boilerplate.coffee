
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
  
  app.set 'session_db_name', (app.get 'session_db_name') or 'session'
  
  console.log 'session db',  (app.get 'session_db_name')

  if (app.get 'session_db_name')
    #app.use express.session secret: (app.get 'secret') or "UNSECURE-STRING", store: new MongoStore({native_parser: false})
    store_opts =
      url: app.get 'session_db_name'
#if app.get('db_password')
#      store_opts.username = app.get 'db_username'
#      store_opts.password = app.get 'db_password'
    
    FileStore = require('session-file-store')(session)
    app.use session
      secret: (app.get 'secret') or "UNSECURE-STRING",
      store: new FileStore(session)

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