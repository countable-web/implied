const request = require("superagent");
const assert = require("assert");
const mongojs = require("mongojs");
const md5 = require("md5");
const bcrypt = require("bcrypt");
const sinon = require("sinon");

const impliedLib = require("../../index");
const sampleData = require('../sample-data');
const testConfig = require('../test-config');

let db = mongojs(testConfig.mongoUrl);

//Start Test Server
const testServer = require('../run-server');
const serverUrl = 'http://' + testConfig.server.host;

describe("Create User JSON API Tests", function() {
    before(async function(){
        await db.collection("users").remove();
        await db.collection("session").remove();
    });
    it("should create a user", async function() {
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser1.email+"&password="+sampleData.testUser1.password);
        assert.equal(res.body.success, true);
        assert.equal(res.body.user.email, sampleData.testUser1.email);
    });

    it("should logout", async function() {
        let res = await request.get(serverUrl + "/logout.json");
    });

    it("should login as test user", async function() {
        let res = await request.get(serverUrl + "/login.json?email="+sampleData.testUser1.email+"&password="+sampleData.testUser1.password);
        assert.equal(res.body.success, true);
        assert.equal(res.body.user.email, sampleData.testUser1.email);
    });

    it("should not be able to create same user twice", async function() {
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser1.email+"&password="+sampleData.testUser1.password);
        assert.equal(res.body.success, false);
    });
});

describe("Create User non-JSON API Tests", function() {
    before(async function(){
        await db.collection("users").remove();
        await db.collection("session").remove();
    });
    it("should create a user", async function() {
        let res = await request.post(serverUrl + "/signup")
        	.send({
        		"email": sampleData.testUser1.email,
        		"password": sampleData.testUser1.password,
	        })

        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });


    it("should be able to confirm user with email-confirmation-token", async function() {
    	let user = await db.collection("users").find({ email: sampleData.testUser1.email });
    	
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser1.email+"&password="+sampleData.testUser1.password);
        assert.equal(res.body.success, false);
    });

    it("should logout", async function() {
        let res = await request.get(serverUrl + "/logout");
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

    it("should login as test user", async function() {
		let res = await request.post(serverUrl + "/login", 
        	{
        		"email": sampleData.testUser1.email,
        		"password": sampleData.testUser1.password
        	}
        );        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

    it("not be able to create same user twice", async function() {
		let res = await request.post(serverUrl + "/signup", 
        	{
        		"email": sampleData.testUser1.email,
        		"password": sampleData.testUser1.password
        	}
        );      
        assert.equal(res.redirects[0], serverUrl + '/signup');  
    });


    it("should be able to confirm user's email", async function(){
        let user = await db.collection("users").findOne({
            "email": sampleData.testUser1.email,
        });

        let res = await request.get(serverUrl + "/confirm-email?token=" + user.email_confirmation_token);
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);

        let newUser = await db.collection("users").findOne({
            "email": sampleData.testUser1.email,
        });
        assert.ok(newUser.confirmed)
    });
});


describe("User Password Reset API Tests", function() {
    let saltRounds = 10;
    let passwordResetToken;

    before(async function(){
        await db.collection("users").remove();
        await db.collection("session").remove();

        let passwordHash = await bcrypt.hash(sampleData.testUser1.password, saltRounds);
        await db.collection("users").insert({
            "email": sampleData.testUser1.email,
            "password": passwordHash,
            "confirmed": true,
            "email_confirmation_token": Math.random()
        });
    });

    it("should send password reset email and set password_reset_token", async function() {
        this.timeout = 10000;

        let mailer = testServer.get('mailer');
        let send_mail_stub = sinon.stub(mailer, "send_mail");
        let userEmail = sampleData.testUser1.email;

        let res = await request.post(serverUrl + "/reset-password-submit", 
            {
                "email": userEmail
            }
        );        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);

        let user = await db.collection("users").findOne({ 
            "email": userEmail
        });
        passwordResetToken = user.password_reset_token;

        assert.ok(send_mail_stub.calledOnce);
        send_mail_stub.calledWithExactly({
            "to": userEmail,
            "subject": "Password Reset",
            "body": "Go here to reset your password: http://" + (testServer.get('host')) + "/reset-password-confirm?" + user.password_reset_token
        });
        console.log("verified sinonjs stub");
        // send_mail_stub.restore();
    });

    it("should reset password with correct password_reset_token", async function() {
        console.log("passwordResetToken: " + passwordResetToken);
        let res = await request.post(serverUrl + "/reset-password-confirm?email=" + sampleData.testUser1.email + "&token=" + passwordResetToken);        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

});

describe("User Password Migration API Tests", function() {
    let salt = 'secret-the-cat';
    let oldPasswordHash = md5(sampleData.testUser1.password + salt);

    before(async function(){
        await db.collection("users").remove();
        await db.collection("session").remove();

        await db.collection("users").insert({
            "email": sampleData.testUser1.email,
            "password": oldPasswordHash,
            "confirmed": false,
            "email_confirmation_token": Math.random()
        });
    });


    it("should login as user", async function() {
        let res = await request.post(serverUrl + "/login", 
            {
                "email": sampleData.testUser1.email,
                "password": sampleData.testUser1.password
            }
        );        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

    it("should update password hash of user to bcrypt", async function() {
        let user = await db.collection("users");

        assert.notEqual(user.password, oldPasswordHash);
    });
});
