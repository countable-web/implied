
# Some utilities
exec = require('child_process').exec

class Plugin
  constructor: ->
    @app = app

module.exports = 
  extend: (obj) ->
    Array::slice.call(arguments, 1).forEach (source) ->
      if source
        for prop of source
          obj[prop] = source[prop]

    obj

  syscall: (command, callback, throws=true) ->
    exec command, (error, stdout, stderr) ->
      if stdout
        console.log "stdout: " + stdout
      if stderr and throws
        console.error command
        throw "stderr: " + stderr
      if error and throws
        console.error command
        throw "exec error: " + error
      callback?(stdout, error or stderr)

  Plugin: Plugin
