
# Common utilities for monexp
# @param db - {mongodb database}
#
module.exports= (app)->
  
  db = app.get 'db'

  flash = (req, message_type, message)->
    if message_type and message
      m = req.session.messages ?= {}
      m[message_type] ?= []
      m[message_type].push message

  # Replacement for req.flash
  flash: flash
 
  # Ensure a user is a staff member (has admin flag)
  staff: (req, res, next) ->
    if req.session.email
      db.collection('users').findOne {email:req.session.email, admin:true}, (err, user)->
        if user
          next()
        else
          flash(req, 'error', 'Not authorized.')
          res.redirect (app.get 'login_url') + "?then=" + req.path
    else
      flash(req, 'error', 'Not authorized.')
      res.redirect (app.get 'login_url') + "?then=" + req.path
