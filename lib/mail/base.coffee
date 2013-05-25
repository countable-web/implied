
# Abstract class for sending transactional emails from an express-implied application.
#
class Mailer
  
  # Send an email.
  #
  # @param opts.subject {string} - email subject to send.
  # @param opts.body {string} - email body to send.
  # @param opts.from {string} - email address to send from.
  # @param opts.to {string} - email addresses to send to.
  send_mail: (opts)->
    console.log opts

module.exports.Mailer = Mailer