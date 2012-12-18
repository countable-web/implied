# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'

module.exports.users=
    
  init:(opts)->
    app = opts.app
    db = opts.db
    Users = db.collection 'users'
    
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

    # Sign Up
    app.get "/signup", (req,res) ->
      res.render 'signup',
        req: req

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
          send_mail
            to: user.email
            subject: "Password Reset"
            body: "Go here to reset your password: http://" + req.host + "/reset-password-confirm?token=" + token
          req.flash?("message", "You've been sent an email with instructions on resetting your password.")
          goto_next req, res
        else
          req.flash?("error", "No user with that email address was found.")
    
    # Password Reset
    app.get "/reset-password", (req,res)->
      res.render 'reset-password'
        token: req.query.token
        req: req

    app.post "/reset-password", (req,res)->
      if req.session.email
        query = {email: req.session.email}
      else
        query = {password_reset_token: req.query.token}
      Users.update query, (err, user) ->
      goto_next req, res

module.exports.blog=
    
  init:(opts)->
    opts.login_url ?= "/login"

    app = opts.app
    db = opts.db

    staff = (req, res, next) ->
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

    app.get "/blog", (req, res) ->
      db.collection('blog').find({public_visible: 'checked'}).sort({pub_date : -1}).limit(3).toArray (err, entries) ->
        res.render 'blog-entries',
          req: req
          email: req.session.email
          entries: entries

    app.get "/blog/:id", (req,res) ->
      db.collection('blog').find({public_visible: 'checked'}, {title:1, image:1}).sort({pub_date : -1}).limit(3).toArray (err, entries) ->
        db.collection('blog').findOne {_id: req.params.id}, (err, rec)->
          console.log err if err

          res.render "blog-entry",
            req: req
            entries: entries
            email: req.session.email
            rec: rec

    app.get "/admin/add-blog", staff, (req, res) ->
      res.render "admin/blog-add",
        req: req
        rec: {}
        email: req.session.email

    app.post "/admin/add-blog", staff, (req, res)->
      req.body.content = req.body.content.replace /\r\n/g, '<br>'
      if req.body.slug_field and req.body.slug_field.length
        req.body._id = req.body.slug_field
      else
        obj_id = new ObjectId()
        req.body._id = obj_id.toString(16)

      if req.files.image
        req.body.image = req.files.image.name
        fs.readFile req.files.image.path, (err, data) ->
          newPath = opts.upload_dir + "site/blog/" + req.files.image.name
          fs.writeFile newPath, data

      db.collection("blog").insert req.body, (err, entry)->
        if err then console.error err
        res.redirect '/admin/blog'

    app.get "/admin/blog", staff, (req, res) ->
      db.collection('blog').find().toArray (err, entries)->
        res.render "admin/blog-list",
          req: req
          email: req.session.email
          entries: entries
    
    app.get "/admin/blog/:id", staff, (req, res) ->
      db.collection('blog').findOne {_id: req.params.id}, (err, rec) ->
        res.render "admin/blog-add",
          title: req.params.collection
          req: req
          form: FORMS['blog']
          email: req.session.email
          rec: rec

    app.post "/admin/blog/:id", staff, (req, res) ->
      obj_id = {_id: req.params.id}
      req.body.content = req.body.content.replace /\r\n/g, '<br>'
      console.log 'IMG', req.files.image
      console.log req.files.image.size > 0

      if req.files.image and req.files.image.size > 0
        req.body.image = req.files.image.name
        fs.readFile req.files.image.path, (err, data) ->
          newPath = opts.upload_dir + "site/blog/" + req.files.image.name
          fs.writeFile newPath, data

      db.collection('blog').update {_id: req.params.id}, {$set: req.body}, false, (err) ->
        if err then return res.send {success:false, error: err}
        res.redirect '/admin/blog'
    
    app.get "/admin/blog/:id/delete", staff, (req, res) ->
      db.collection('blog').remove {_id: req.params.id}, (err, rec) ->
        res.redirect "/admin/blog"

    FORMS = 
      pages:
        print: 'paths'
        fields: [
            name:'title'
          ,
            name:'path'
          ,
            name:'content'
            type:'textarea'
          ,
            name:'meta'
        ]

      blog:
        print: 'paths'
        fields: [
            name: 'pub_date'
          ,
            name: 'name'
          ,
            name: 'title'
          ,
            name: 'content'
            type: 'textarea'
          ,
            name: 'teaser'
          ,
            name: 'slug_field'
        ]

module.exports.admin=
  init:(opts)->
    app = opts.app
    db = opts.db
    forms = opts.forms or {}

    staff = (req, res, next) ->
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
    
    app.get "/admin", staff, (req,res) ->
      res.render 'admin/admin',
        req:req

    app.get "/admin/:collection", staff, (req,res) ->
      db.collection(req.params.collection).find().toArray (err, records)->
        res.render "admin-list",
          title: req.params.collection
          form: forms[req.params.collection]
          req: req
          email: req.session.email
          records: records

    app.get "/admin/:collection/:id", staff, (req,res) ->
      db.collection(req.params.collection).findOne {_id: new ObjectId(req.params.id)}, (err, rec)->
        res.render "admin-object",
          title: req.params.collection
          req: req
          form: forms[req.params.collection]
          email: req.session.email
          rec: rec

    app.post "/admin/:collection/:id", staff, (req,res) ->
      db.collection(req.params.collection).update {_id: new ObjectId(req.params.id)}, {$set: req.body}, (err)->
        res.redirect '/admin/'+req.params.collection