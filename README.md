implied
=======

Reusable webapp parts for Express with MongoDB.

Usage:

```javascript

var implied = require('implied');

implied(app); // initialize the library.

app.plugin('mongo', 'boilerplate', 'sendgrid', 'users'); // choose plugins you want in dependency order. Currently many things depend on 'mongo'.

```

### Mongo

The 'mongo' module wraps mongojs (a mongodb client), and sets an app variable with the database reference for use by other modules.

```javascript

app.plugin('mongo');
app.get('db').collection('mycollection').find({}).toArray(function(items){
  console.log(items);
});

```

### Users

The 'users' module handles user registration, logins and password resets. Users are stored in MongoDB so this depends on the 'mongo' module.

```javascript
app.plugin('mongo', 'boilerplate', 'users'); // to install
```

