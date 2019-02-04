const express = require("express");
const path = require("path");
const session = require("express-session");

const implied = require("../index");
const testConfig = require("./test-config");

//Set Config Path
process.env.CONFIG_FILENAME = testConfig.impliedConfigPath;

//Start server
let expressApp = express();
expressApp.listen(3000);

let app = implied(expressApp, {
	listen: false
});

app.use(session({
  secret: 'keyboard cat',
  resave: false,
  saveUninitialized: true,
  cookie: { secure: false }
}));

app.set("view engine", "jade");
app.set("app_name", "implied-test");

app.set("view engine", "jade");
app.set("views", path.join(__dirname, '../views'));
console.log(path.join(__dirname, '../views'))

app.plugin(["mongo", "sendgrid", "boilerplate", "users", "routing", "logging"]);

app.get("/", function(req, res){
	return res.render("layout.jade", {
		req: req
	});
})

module.exports = app;
