# Express Mongo Users
md5 = require 'MD5'

module.exports.users=
  init:(app, db)->

    app.post "/login", (req,res) ->
      db.collection('users').findOne {email:req.body.email, password:req.body.password}, (err, user)->
        if user
          req.session.email = user.email
          req.flash?("success", "You've been logged in.")
          res.redirect req.query.then or req.body.then or '/'
        else
          req.flash?("error", "Email or password incorrect.")
          res.redirect req.path

    app.get "/logout", (req, res) ->
      req.session.email = null
      req.flash?("success", "You've been safely logged out")
      res.redirect req.query.then or '/'

    app.get "/signup", (req,res) ->
      res.render 'signup',
        req: req

    app.post "/signup", (req,res) ->
      if req.body.email and req.body.password
        # Check if user exists.
        db.collection('users').find({email: req.body.email}).toArray (err, users)->
          if users.length is 0
            db.collection('users').insert req.body, (err, user)->
              req.session.email = user.email
              res.redirect req.query.then or '/'
          else
            req.flash?("error", "That user already exists.")
            res.render 'signup',
              req: req
      else
        req.flash?("error", "Please enter a username and password.")
        res.render 'signup',
          req: req