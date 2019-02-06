# Implied - Reusable ExpressJS Components

Implied is a tool that reduces boilerplate cruft in your ExpressJS web app by providing reusable web app components.

With Implied's plugin system you can choose what components you want to use for your app, in just one line.

![Project Status](https://img.shields.io/badge/status-0.2.11-green.svg)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/3c3e66e6ee1346d180109d98e20fb5df)](https://www.codacy.com/app/arielleb/implied?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=countable-web/implied&amp;utm_campaign=Badge_Grade)


## Quickstart

First, install `implied` with npm:

```
$ npm install --save-dev implied 
```

or install with yarn:

```
$ yarn add --dev implied
```

Then add `config.js` to your Express app's root directory. (See [Configuration](#configuration) for more details)

```config.js
module.exports = function(app){
    app.set('port', 3000);
}
```

Then in your `app.js` pass your ExpressJS app to implied and enable plugins
```
const implied = require('implied');
const express = require('express');

...

var app = implied(app, {
    listen: true
});

app.plugin('mongo', 'boilerplate', 'sendgrid', 'users'); // choose plugins you want in dependency order. Currently many things depend on 'mongo'.
```

That's it! Your app should be live at `localhost:3000`

## Testing

Our testing enivronment uses docker for setup and configuration

To run tests, run this command
`docker-compose up`

## Configuration

Implied's configuration is done with the `config.js` file. To set an option for Implied, open/create your `config.js` file (in your project root) and add `app.set($property_name, 'somevalue')` to set the `property_name` setting to the value `somevalue`.

| Property            | Valid Values        | Default                  | Description                                                                                                             | Required? |
|---------------------|---------------------|--------------------------|-------------------------------------------------------------------------------------------------------------------------|-----------|
| app_name            | any string          | project root folder name | Name of the implied application. Used to set the database name and used in transactional emails                         | No        |
| dir                 | any valid path      | path to project root     | Sets the path to the project root. Used to locate implied's config file (which is at the root) and the views directory. | No        |
| upload_dir          | any string          | app_name                 | Sets the name of the upload directory                                                                                   | No        |
| listen              | boolean             | false                    | If enabled makes implied listen on the port given in configuration                                                      | No        |
| login_url           | any valid URI       | /login                   | Sets the name of the login route                                                                                        | No        |
| forms               | object              | {}                       | Dictionary/hashmap containing jade layouts for displaying each collection in admin panel                                | No        |
| logoutSSO_Discourse | any valid URL       | null                     | Callback URL for discourse logout SSO                                                                                   | No        |
| db_name             | any valid mongo url | app_name                 | Mongo URI used to connect to specific database                                                                          | No        |
| admin_email         | any valid email     | no-reply@example.com     | Reply email used when sending transactional emails to users                                                             | No        |
| error_email         | any valid email     | admin_email              | Email address that errors are sent to when running in production mode                                                   | No        |
| port                | integer             | 3000                     | Port that Implied will bind to and listen on                                                                            | No        |
| host                | valid url/domain    | localhost                | Host that Implied will listen on. Also used for session authentictation                                                 | No        |

### Mongo

The 'mongo' module wraps [mongojs](https://github.com/mafintosh/mongojs) (a mongodb client), and sets an app variable with the database reference for use by other modules.

```javascript

app.plugin('mongo');
app.get('db').collection('mycollection').find({}).toArray(function(items){
  console.log(items);
});

```

### Boilerplate

A reasonable set of defaults for express middleware, for a typical website. It includes bodyParser, cookies, sessions. If you do need extra middleware in between the default middleware (ordinally), you won't be able to use this.

```javascript

app.plugin('boilerplate');

```

### Users

The 'users' module handles user registration, logins and password resets. Users are stored in MongoDB so this depends on the 'mongo' module.

```javascript
app.plugin('mongo', 'boilerplate', 'users'); // to install
```

You'll need the following views with HTML forms, unless you'd rather use the rest interface.

views/pages/login.jade - contains a form with an input of name "password" and "email", at least.
views/pages/signup.jade - contains a form with an input of name "password" and "email", at least.
views/pages/password-reset-submit.jade - contain a form with an input of name "email".

### Hooks
You can trigger something to happen when a user signs up as follows:

```
implied.on('signup', function(user){});
```

### Sendgrid

Provides other modules with a wrapped sendgrid email client, app.get('mailer').

```javascript

app.plugin('sendgrid');
app.get('mailer').send_mail({to:'test@example.com', subject:'Test', body:'You are reading the contents of a test email... Bored?''});

```

### Contributing

Follow the basic design idea of being pragmatic please. New features should directly solve specific problems, and not introduce abstraction without doing so. And yes, implied is written in coffeescript. If you have a strong opinion about this... please just relax! The controversy over coffeescript is much more costly than the very minimal difference between using it and javascript :)


