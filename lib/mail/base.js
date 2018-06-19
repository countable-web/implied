/*
 * Abstract class for sending transactional emails from an express-implied application.
 *
 */
var Mailer;

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
        return console.log(opts);
    };

    return Mailer;

})();

module.exports.Mailer = Mailer;
