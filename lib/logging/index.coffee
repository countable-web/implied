
express = require 'express'

# Implied logging module.
#
module.exports = (app)->

  mailer = (app.get 'mailer')

  app.configure "development", ->
    app.use express.errorHandler
      dumpExceptions: true
      showStack: true

  app.set 'view options', layout: false

  # prod_error - handle an error on a production site.
  # @param opts.title {string} 
  # @param opts.message {string}
  # @param callback (err)->
  prod_error = (opts, callback)->

    mailer.send_mail
      subject: "Error on " + (app.get('host') or "website") + " - " + opts.title
      from: "errors@mrblisted.ca"
      to: [app.get('error_email')]
      body: opts.message
    , (success, message)->
      if success
        callback?() #No issues :)
      else
        console.error "ERROR EMAIL FAILED: ",message
        callback? "ERROR EMAIL FAILED: ",message

  app.configure "production", ->
    #app.use express.errorHandler()
    app.use (err, req, res, next)->

      message = """Details:
  ========

   - location : #{req.host}#{req.originalUrl}
   - xhr : #{req.xhr}
  """

      message += """Stack Trace:
  ============

  #{err.stack}

  Request:
  ========

  #{req.method} #{req.protocol.toUpperCase()}/#{req.httpVersionMajor}.#{req.httpVersionMinor}


  """
      for own k,v of req.headers
        message += " - " + k + " : " + v + "\n"
     
      if req.session
        message += """

  Session:
  ========

  """

        for own k,v of req.session
          message += " - " + k + " : " + v + "\n"


      console.error message

      prod_error
        title: err.name
        message: message

      res.render '500'

  app.get "/client_error", (req, res)->
    
    unless req.query.message
      return res.send
        message: '/client_error: Failed - No error message specified.'
        success: false

    message = """DETAILS:
    ========

    """
    for own k,v of req.query
      message += " - " + k + " : " + v + "\n"
    
    # Only show errors on production sites.
    if process.env.NODE_ENV is 'production'
      prod_error
        title: "Error Caught on Client"
        message: message
      , (err)->
        res.send {success:true}
    # For dev sites, warn about possible config issue.
    else
      console.error 'DEV SITE RECIEVED CLIENT ERROR:', req.query
      res.send
        success: true
        message: 'Client error ignored because this is a development site.'