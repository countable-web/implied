
mongolian = require 'mongolian'
ObjectId = mongolian.ObjectId
path = require 'path'

clear = (val)->
  type = typeof val
  if type is 'number'
    0
  else
    ''
  
module.exports = (app, opts={})-> 
    
    opts.login_url ?= "/login"

    db = app.get 'db'

    forms = opts.forms or {}
    
    staff = app.get('plugins').users.staff
    unless staff
      throw "Admin requires the user module be installed."

    template_base = path.join(__dirname, "..", "views")
    
    # List of all collections.
    app.get "/admin", staff, (req,res) ->
      db.collectionNames (err, collections)->
        res.render path.join(template_base, "admin"),
          collections: collections

    # List of objects in collections
    app.get "/admin/:collection", staff, (req,res) ->
      db.collection(req.params.collection).find().toArray (err, records)->
        res.render path.join(template_base, "admin-list"),
          title: req.params.collection
          form: forms[req.params.collection]
          records: records

    # New object
    app.get "/admin/:collection/add", staff, (req,res) ->
      db.collection(req.params.collection).findOne (err, rec)->
        for own k,v of rec
          rec[k] = clear v
        res.render path.join(template_base, "admin-object"),
          title: req.params.collection
          form: forms[req.params.collection]
          rec: rec

    # Show / Edit an object
    app.get "/admin/:collection/:id", staff, (req,res) ->
      db.collection(req.params.collection).findOne {_id: new ObjectId(req.params.id)}, (err, rec)->
        res.render  path.join(template_base, "admin-object"),
          title: req.params.collection
          form: forms[req.params.collection]
          rec: rec

    # Delete an object
    app.get "/admin/:collection/:id/del", staff, (req,res) ->
      db.collection(req.params.collection).remove {_id: new ObjectId(req.params.id)}, (err, rec)->
        res.redirect '/admin/'+req.params.collection

    # Save an object
    app.post "/admin/:collection/:id", staff, (req,res) ->
      if req.params.id is 'add'
        db.collection(req.params.collection).insert req.body, (err)->
          res.redirect '/admin/'+req.params.collection
      else
        db.collection(req.params.collection).update {_id: new ObjectId(req.params.id)}, {$set: req.body}, (err)->
          res.redirect '/admin/'+req.params.collection

    app.post "/admin/api/:collection/:id", staff, (req,res) ->
      db.collection(req.params.collection).update {_id: new ObjectId(req.params.id)}, {$set: req.body}, (err)->
        res.send {
          message: err
          success: not err
        }