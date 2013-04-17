exec = require('child_process').exec

# Common utilities for monexp
# @param db - {mongodb database}
#
module.exports= (opts)->
  
  db = opts.db
  
  # Canonical system call. 
  syscall: (command, callback, throws=true) ->
    child = exec command, (error, stdout, stderr) ->
      if stdout
        console.log "stdout: " + stdout
      if stderr and throws
        console.error command
        throw "stderr: " + stderr
      if error and throws
        console.error command
        throw "exec error: " + error
      callback?(stdout, error or stderr)

  # Replacement for req.flash
  flash: (req, message_type, message)->
    if message_type and message
      m = req.session.messages ?= {}
      m[message_type] ?= []
      m[message_type].push message
  
  # Ensure a user is a staff member (has admin flag)
  staff: (req, res, next) ->
    if req.session.email
      db.collection('users').findOne {email:req.session.email, admin:true}, (err, user)->
        if user
          next()
        else
          req.flash?('Not authorized.')
          res.redirect opts.login_url + "?then=" + req.path
    else
      req.flash?('Not authorized.')
      res.redirect opts.login_url + "?then=" + req.path