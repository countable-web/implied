
mongojs = require 'mongojs'

me = module.exports = (app)->
  unless app.get 'db_name'
    app.set 'db_name', app.get 'app_name'
  connect_string = app.get 'db_name'
  #if app.get 'db_password'
  #    connect_string = (app.get 'db_username') + ':' + (app.get 'db_password') + '@localhost/' + connect_string
  
  app.set('db', mongojs(connect_string, [], {authMechanism: 'ScramSHA1'}))

me.oid_str = (inp)->
  (me.oid inp).toString()


me.oid = (inp)->
  if inp instanceof mongojs.ObjectId
    return inp
  else if inp.bytes
    result = (implied.util.zpad(byte.toString(16),2) for byte in inp.bytes).join ''
    return mongojs.ObjectId result
  else
    return mongojs.ObjectId ''+inp