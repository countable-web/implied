exec = require('child_process').exec

module.exports = 

  # Canonical system call. 
  syscall: (command, callback, throws=true) ->
    child = exec command, (error, stdout, stderr) ->
      if stdout
        console.log "stdout: " + stdout
      if stderr and throws
        console.error command
        throw "stderr: " + stderr
      if error and throws
        console.error command
        throw "exec error: " + error
      callback?(stdout, error or stderr)