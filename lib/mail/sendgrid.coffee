
base = require './base'
util = require '../../util'

class Mailer extends base.Mailer

  constructor: (app)->
    super
    @sendgrid = new (require("sendgrid").SendGrid) @app.get('email_username'), @app.get 'email_password'

  # Send an email.
  #
  # @param opts.body {string}
  # @param opts.subject {string}
  # @param opts.from {string}
  # @param opts.to {array}
  send_mail: (opts, callback) ->
    defaults = 
      from: @default_from
      text: opts.body
      headers:
        'X-SMTPAPI': '{"category": '+(@app.get 'name')+'}'
      
    @sendgrid.send util.extend({},defaults,opts), (success, message) ->
      console.error message unless success
      err = null
      if not success then err = message
      callback?(err)

module.exports = (app)->
  app.set 'mailer', new Mailer app