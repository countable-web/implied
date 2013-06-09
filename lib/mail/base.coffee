
# Abstract class for sending transactional emails from an express-implied application.
#
class Mailer
  
  constructor: (app)->
    @app = app
    @default_from = (app.get 'email_default_from') or (app.get 'admin_email') or 'no-reply@example.com'

  # Send an email.
  #
  # @param opts.subject {string} - email subject to send.
  # @param opts.body {string} - email body to send.
  # @param opts.from {string} - email address to send from.
  # @param opts.to {string} - email addresses to send to.
  send_mail: (opts)->
    console.log opts

module.exports.Mailer = Mailer