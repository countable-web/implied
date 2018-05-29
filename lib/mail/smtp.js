
/*
 *
 */
var Mailer;
var nodemailer = require('nodemailer');

Mailer = (function() {
  function Mailer(app) {
    this.app = app;
    this.default_from = (app.get('email_default_from')) || (app.get('admin_email')) || 'no-reply@example.com';
    this.default_from_name = (app.get('email_default_from_name')) || this.default_from;
  }


  /*
   * Send an email.
   *
   * @param opts.subject {string} - email subject to send.
   * @param opts.body {string} - email body to send.
   * @param opts.from {string} - email address to send from.
   * @param opts.to {string} - email addresses to send to.
   */

  Mailer.prototype.send_mail = function(opts) {
    // create reusable transporter object using the default SMTP transport
    let transporter = nodemailer.createTransport({
        host: app.get('email_host'),
        port: 587,
        secure: false, // true for 465, false for other ports
        auth: {
            user: app.get('email_username'),
            pass: app.get('email_password')
        }
    });

    opts.text = opts.body;
    delete opts.body;
    // send mail with defined transport object
    transporter.sendMail(opts, (error, info) => {
        if (error) {
            return console.log(error);
        }
        console.log('Message sent: %s', info.messageId);
        // Preview only available when sending through an Ethereal account
        console.log('Preview URL: %s', nodemailer.getTestMessageUrl(info));

        // Message sent: <b658f8ca-6296-ccf4-8306-87d57a0b4321@example.com>
        // Preview URL: https://ethereal.email/message/WaQKMgKddxQDoou...
    });
  };

  return Mailer;

})();

module.exports.Mailer = Mailer;
