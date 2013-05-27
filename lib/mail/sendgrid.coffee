
base = require './base'
util = require '../../util'

class Mailer extends base.Mailer

  constructor: (app)->
    @app = app
    @sendgrid = new (require("sendgrid").SendGrid) @app.get('username'), @app.get 'password'

  # Send an email.
  #
  # @param opts.body {string}
  # @param opts.subject {string}
  # @param opts.from {string}
  # @param opts.to {array}
  send_mail: (opts, callback) ->
    defaults = 
      from: app.get 'email_default_from_address'
      text: opts.body
      headers:
        'X-SMTPAPI': '{"category": '+(@app.get 'name')+'}'
      
    @sendgrid.send util.extend({},defaults,opts), (success, message) ->
      console.error message unless success
      callback?(success, message)

module.exports = (app)->
  app.set 'mailer', new Mailer app