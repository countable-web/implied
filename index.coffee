# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'
fs = require 'fs'
async = require 'async'

videos = require './videos'

users = (opts)->
    
    opts.salt ?= 'secret-the-cat'

    app = opts.app
    db = opts.db
    Users = db.collection 'users'
    
    statics = (arr) ->
      arr.forEach (item)->
        app.get '/'+item, (req,res)->
          res.render item,
            req: req

    statics ['signup', 'login', 'reset-password-confirm', 'reset-password-submit']

    # Forward a request based on "then" hints in it.
    goto_next = (req,res)->
      res.redirect req.query.then or req.body.then or '/'

    # Replacement for req.flash
    flash = (req, message_type, message)->
      if message_type and message
        m = req.session.messages ?= {}
        m[message_type] ?= []
        m[message_type].push message

    # Log in
    # HTTP API:
    # @param then - page to redirect to on success.
    # @param onerror - page to redirect to on failure.
    # @param email - user to log in.
    # @param password - the user's password.
    app.post "/login", (req,res) ->

      Users.findOne
        email:req.body.email
        $or: [
          {password: req.body.password}
          {password: md5(req.body.password + opts.salt)}
        ]
      , (err, user)->
        if user
          req.session.email = user.email
          req.session.admin = user.admin
          flash req, "success", "You've been logged in."
          goto_next req, res
        else
          flash req, "error", "Email or password incorrect."
          res.redirect req.body.onerror or req.path

    app.get "/logout", (req, res) ->
      req.session.email = null
      flash req, "success", "You've been safely logged out"
      goto_next req, res

    app.post "/signup", (req,res) ->
      if req.body.email and req.body.password
        req.body.password = md5(req.body.password + opts.salt)
        # Check if user exists.
        Users.find({email: req.body.email}).toArray (err, users)->
          if users.length is 0
            Users.insert req.body, (err, user)->
              req.session.email = user.email
              req.session.admin = user.admin
              goto_next req, res
          else
            flash req, "error", "That user already exists."
            res.render 'signup',
              req: req
      else
        flash req, "error", "Please enter a username and password."
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
          flash req, "message", "You've been sent an email with instructions on resetting your password."
          goto_next req, res
        else
          flash req, "error", "No user with that email address was found."

    app.post "/reset-password-confirm", (req,res)->
      if req.session.email
        query = {email: req.session.email}
      else
        query = {password_reset_token: req.query.token}
      Users.update query, {$set:{password:req.body.password}}, (err, user) ->
        if err
          flash req, 'error', 'Password reset failed'
        else
          flash req, 'success', 'Password was reset'
        goto_next req, res

admin = require './admin'

module.exports.init = (opts)->
  if opts.videos
    videos opts

  if opts.users
    users opts

  if opts.admin
    admin opts



