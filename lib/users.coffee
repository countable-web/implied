md5 = require 'MD5'
#uuid = require 'node-uuid'
events = require 'events'
util = require '../util'

me = module.exports = (app, opts)->

    salt = app.get('secret') ? 'secret-the-cat'
    if not app.get 'welcome_email'
      app.set 'welcome_email', "Thanks for signing up for " + app.get("app_name")
    
    db = app.get 'db'
    mailer = app.get 'mailer'
    Users = db.collection 'users'
    login_url = "/login"

    # Ensure a user is a staff member (has admin flag)
    me.staff = (req, res, next) ->
      if req.session.email
        db.collection('users').findOne {email:req.session.email, admin:true}, (err, user)->
          if user
            next()
          else
            flash(req, 'error', 'Not authorized.')
            res.redirect login_url + "?then=" + req.path
      else
        flash(req, 'error', 'Not authorized.')
        res.redirect login_url + "?then=" + req.path

    flash = (require '../util').flash

    
    # Forward a request based on "then" hints in it.
    goto_then = (req, res)->
      res.redirect req.query._then or req.body._then or '/'

    
    goto_error = (req, res)->
      res.redirect req.query.onerror or req.body.onerror or req.originalUrl


    # User succeeded in authenticating.
    login_success = (req, user)->
      req.session.email = user.email or "no email"
      req.session.admin = user.admin
      req.session.user = user
      req.session.user._id = user._id.toString()
      if req.session.user.group_id
        req.session.user.group_id = user.group_id.toString()
      # This user won't have to log in for a 2 weeks
      req.session.cookie.maxAge = 14 * 24 * 60 * 60 * 1000


    # create a query for fetching a user based on an http request.
    # Note: lookups are cast to lowercase under the assumption they're stored that way.
    # @param params.username
    # @param params.email
    build_lookup_query = (params)->
      q = {
        $or:[]
      }
      if typeof params.username is 'string'
        q.$or.push {username: params.username.replace(/\s/g, "").toLowerCase()}
        q.$or.push {email: params.username.replace(/\s/g, "").toLowerCase()}
      if typeof params.email is 'string'
        q.$or.push {username: params.email.replace(/\s/g, "").toLowerCase()}
        q.$or.push {email: params.email.replace(/\s/g, "").toLowerCase()}
      q

    # Generic login function, used with any HTTP based transport.
    login = (req, callback)->
      # Email and password provided using any request method, GET, POST or url params.
      lookup = build_lookup_query
        username: req.param 'username'
        email: req.param 'email'
      password = req.param 'password'
      query = 
        $and: [
            lookup
          ,
            $or: [
              {password: password}
              {password: md5(password + salt)}
            ]
        ]
      
      db.collection('users').findOne query, (err, user)->
        if user
          # If this app requires email confirmation, enforce it.
          if not user.confirmed and app.get 'email_confirm'
            callback
              success: false
              message: 'Please confirm your email address before logging in.'
          else
            login_success req, user
            callback
              success: true
              user: user
              message: 'You have been logged in.'
        else
          callback
            success: false
            message: 'Email or password incorrect.'


    signup = (req, callback)->
      
      user = {}

      for own k,v of req.query
        if k.substr(0,1) isnt '_'
          user[k] = me.sanitize v, k

      for own k,v of req.body
        if k.substr(0,1) isnt '_'
          user[k] = me.sanitize v, k

      user.email = user.email.replace(" ", "").toLowerCase()
      user.confirmed = false
      user.email_confirmation_token = Math.random() #uuid.v4()
      
      unless user.email and user.password
        callback
          success: false
          message: "Please enter a username and password."

      user.password = md5(user.password + salt)

      # Validate the email address.
      unless /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/.test user.email
        callback
          success: false
          message: "Invalid email address."

      # Called after other signup validation.
      complete = (errs)->
        if errs and errs.length
          callback
            success: false
            message: errs.join ","

        lookup = build_lookup_query user

        # Check if user exists.
        Users.find(
          lookup
        ).toArray (err, users)->
          if err
            throw err

          if users.length is 0 or users[0].pending
            
            Users.update lookup, user, {upsert: true}, (err, result)->
              
              Users.findOne {email:user.email}, (err, user)->

                if err
                  return callback
                    success: false
                    message: err

                mailer?.send_mail
                  to: user.email
                  subject: app.get("welcome_email_subject") or "Welcome!"
                  body: util.format app.get("welcome_email"),
                    first_name: user.first_name or user.email
                    confirm_link: "http://" + (app.get 'host') + "/confirm-email?token=" + user.email_confirmation_token
                
                # User creation event.
                me.emitter.emit 'signup', user

                # If no confirmation is required, sign the person in.
                if app.get 'email_confirm'
                  callback
                    success: true
                    message: 'Thanks for signing up! Please follow the instructions in your welcome email.'
                else
                  login_success req, user
                  callback
                    success: true
                    user: user
                    message: 'Thanks for signing up!'
              
          else
            callback
              success: false
              message: "That user already exists."

      validator = app.get 'user_signup_validator'
      if validator
        validator req, complete
      else
        complete null


    logout = (req)->
      req.session.email = null
      req.session.admin = null
      req.session.user = null


    # Log in
    # HTTP API:
    # @param then - page to redirect to on success.
    # @param onerror - page to redirect to on failure.
    # @param email - user to log in.
    # @param password - the user's password.
    app.post "/login", (req,res) ->

      login req, (result)->

        if result.success
          flash req, "success", result.message
          goto_then req, res
        else
          flash req, "error", result.message
          goto_error req, res


    app.get "/logout", (req, res) ->
      logout req
      flash req, "success", "You've been safely logged out"
      goto_then req, res


    app.get "/logout.json", (req, res) ->
      logout req
      res.send
        success: true


    app.post "/signup", (req, res) ->

      signup req, (result)->

        if result.success
          flash req, "success", result.message
          goto_then req, res

        else
          flash req, "error", result.message
          goto_error req, res


    app.get "/login.json", (req, res) ->

      login req, (result)->
        res.send result

    
    console.log ('binding, signup.json')

    app.get "/signup.json", (req, res) ->

      signup req, (result)->
        res.send result


    server_path = (req)->
      url = req.protocol + "://" + req.host
      if req.port and req.port isnt 80 then url += ":" + req.port
      url


    # Email Confirmation
    app.get "/confirm-email", (req, res)->

      query = {email_confirmation_token: req.query.token}
      Users.update query, {$set:{confirmed:true}}, (err) ->
        if err
          flash req, 'error', 'Email confirmation failed'
          goto_then req, res
        else
          Users.findOne query, (err, user)->
            if err then throw err
            if not user then throw 'User does not exist'
            login_success req, user
            if user
              flash req, 'success', 'Email confirmed'
            goto_then req,res


    # Password Forgotten
    app.post "/reset-password-submit", (req,res)->
      Users.findOne {email: req.body.email}, (err, user) ->
        if user
          token = "" + Math.random() #uuid.v4()
          Users.update({_id: util.oid(user._id)}, {$set:{password_reset_token:token}})
          mailer?.send_mail(
              to: user.email
              subject: "Password Reset"
              body: "Go here to reset your password: http://" + (app.get 'host') + "/reset-password-confirm?token=" + token
            ,
              (err)->
                (console.error err) if err
          )

          flash req, "success", "You've been sent an email with instructions on resetting your password."
          goto_then req, res
        else
          flash req, "error", "No user with that email address was found."
          res.render 'pages/reset-password-submit'


    app.post "/reset-password-confirm", (req,res)->
      if req.session.email
        query = {email: req.session.email}
      else
        query = {password_reset_token: req.query.token}

      Users.findOne query, (err, user) ->
        if err
          flash req, 'error', 'Password reset failed'
          goto_then req, res

        if user
          # Invalidated password reset url and reset the password
          new_token = "" + Math.random()
          Users.update query, {$set:{password: md5(req.body.password + salt), password_reset_token: new_token}}, (err) ->
            if err
              flash req, 'error', 'Password reset failed'
            else
              flash req, 'success', 'Password was reset'
            goto_then req, res
        else
          flash req, 'error', 'Invalid password reset link'
          goto_then req, res


    # User imitation. Allows staff to simulate other users for debugging.
    # Hopefully not used for anything too devious.
    app.get "/become-user/:id", me.staff, (req,res)->
      Users.findOne {_id: util.oid(req.params.id)}, (err, user)->
        login_success req, user
        goto_then req, res


me.emitter = new events.EventEmitter()


# Ensure a user is a member
me.restrict = (req, res, next) ->
  if req.session.email
    next()
  else
    res.redirect "/login" + "?then=" + req.path


# Ensure a user is a member, for rest API
me.restrict_rest = (req, res, next) ->
  if req.session.email
    next()
  else
    res.send
      success: false
      message: 'Not authenticated.'

me.sanitize = (s, field_name)->
    # if it's an object, use an OID
    if field_name and field_name.substr(field_name.length-3) is "_id"
      try
        return util.oid(s)
      catch error
        console.error 'bad id string:', s, error
    else
      s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;')
