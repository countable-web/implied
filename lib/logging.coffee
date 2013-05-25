
# Implied logging module.
#
module.exports = (opts)->

  mailer = opts.mailer
  app = opts.app

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

    mailer
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

      message = """Stack Trace:
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