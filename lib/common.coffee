
# Common utilities for monexp
# @param db - {mongodb database}
#
module.exports= (app)->
  
  db = app.get 'db'

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
