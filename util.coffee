
# Some utilities
exec = require('child_process').exec
mongojs = require 'mongojs'




class Plugin
  constructor: ->
    @app = app

me = module.exports = 

  extend: (obj) ->
    Array::slice.call(arguments, 1).forEach (source) ->
      if source
        for prop of source
          obj[prop] = source[prop]
    obj

  syscall: (command, callback, throws=true) ->
    exec command, (error, stdout, stderr) ->
      #if stdout
      #  console.log "stdout: " + stdout
      if stderr and throws
        console.error command
        throw "stderr: " + stderr
      if error and throws
        console.error command
        throw "exec error: " + error
      callback?(stdout, error or stderr)


  get_file_extension: (fname)->
    fname.substr((Math.max(0, fname.lastIndexOf(".")) || Infinity) + 1)

  flash: (req, message_type, message)->
    if message_type and message
      m = req.session.messages ?= {}
      m[message_type] ?= []
      m[message_type].push message

  Plugin: Plugin

  format: (str, dict)->
    str.replace /\{([^\}]+)\}/g, (match, $1)->
      dict[$1] or ''
  
  zpad: (num, zeros=0)->
    num = ''+num
    while num.length < zeros
      num = '0' + num
    num

  oid_str: (inp)->
    (me.oid inp).toString()

  oid: (inp)->
    if inp instanceof mongojs.ObjectId
      return inp
    else if inp.bytes
      result = (implied.util.zpad(byte.toString(16),2) for byte in inp.bytes).join ''
      return mongojs.ObjectId result
    else
      return mongojs.ObjectId ''+inp
