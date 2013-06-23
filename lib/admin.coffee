

module.exports = (app, opts={})-> 
    opts.login_url ?= "/login"

    db = app.get 'db'
    
    forms = opts.forms or {}

    staff = app.get('implied').users.staff
    
    unless staff
      throw "Admin requires the user module be installed."

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
    app.get "/admin/:collection", staff, (req,res) ->
      db.collection(req.params.collection).find().toArray (err, records)->
        res.render "admin/admin-list",
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