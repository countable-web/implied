
module.exports= (opts)->
  db = opts.db
  
  common=

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