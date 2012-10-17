# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'

module.exports.users=
    
  init:(opts)->

    app = opts.app
    db = opts.db
    Users = db.collection 'users'
    
    statics = (arr) ->
      arr.forEach (item)->
        console.log item
        app.get '/'+item, (req,res)->
          res.render item,
            req: req

    statics ['signup', 'login', 'reset-password-confirm', 'reset-password-submit']

    # Forward a request based on "then" hints in it.
    goto_next = (req,res)->
      res.redirect req.query.then or req.body.then or '/'

    # Log in
    app.post "/login", (req,res) ->
      Users.findOne {email:req.body.email, password:req.body.password}, (err, user)->
        if user
          req.session.email = user.email
          req.flash?("success", "You've been logged in.")
          goto_next req, res
        else
          req.flash?("error", "Email or password incorrect.")
          res.redirect req.path

    app.get "/logout", (req, res) ->
      req.session.email = null
      req.flash?("success", "You've been safely logged out")
      goto_next req, res

    app.post "/signup", (req,res) ->
      if req.body.email and req.body.password
        # Check if user exists.
        Users.find({email: req.body.email}).toArray (err, users)->
          if users.length is 0
            Users.insert req.body, (err, user)->
              req.session.email = user.email
              goto_next req, res
          else
            req.flash?("error", "That user already exists.")
            res.render 'signup',
              req: req
      else
        req.flash?("error", "Please enter a username and password.")
        res.render 'signup',
          req: req
    
    server_path = (req)->
      url = req.protocol + "://" + req.host
      if req.port and req.port isnt 80 then url += ":" + req.port
      url

    # Password Forgotten
    app.post "/reset-password-submit", (req,res)->
      Users.findOne {email: req.body.email}, (err, user) ->
        if user
          token = uuid.v4()
          Users.update({_id:user._id}, {$set:{password_reset_token:token}})
          opts.mailer?(
            to: user.email
            subject: "Password Reset"
            body: "Go here to reset your password: http://" + opts.host + "/reset-password-confirm?token=" + token
          )
          console.log 'sent'
          req.flash?("message", "You've been sent an email with instructions on resetting your password.")
          goto_next req, res
        else
          req.flash?("error", "No user with that email address was found.")

    app.post "/reset-password-confirm", (req,res)->
      if req.session.email
        query = {email: req.session.email}
      else
        query = {password_reset_token: req.query.token}
      Users.update query, {$set:{password:req.body.password}}, (err, user) ->
        if err
          req.flash 'error', 'Password reset failed'
        else
          req.flash 'success', 'Password was reset'
        goto_next req, res

