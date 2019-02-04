const request = require("superagent");
const assert = require("assert");
const mongojs = require("mongojs");
const md5 = require("md5");

const impliedLib = require("../../index");
const sampleData = require('../sample-data');
const testConfig = require('../test-config');

let db = mongojs(testConfig.mongoUrl);

//Start Test Server
const testServer = require('../run-server');
const serverUrl = 'http://' + testConfig.server.host + ":" + testConfig.server.port;

describe("Create User JSON API Tests", function() {
	before(function(){
		db.collection("users").remove();
	});

    it("should create a user", async function() {
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser.email+"&password="+sampleData.testUser.password);
        assert.equal(res.body.success, true);
        assert.equal(res.body.user.email, sampleData.testUser.email);
    });

    it("should logout", async function() {
        let res = await request.get(serverUrl + "/logout.json");
    });

    it("should login as test user", async function() {
        let res = await request.get(serverUrl + "/login.json?email="+sampleData.testUser.email+"&password="+sampleData.testUser.password);
        assert.equal(res.body.success, true);
        assert.equal(res.body.user.email, sampleData.testUser.email);
    });

    it("should not be able to create same user twice", async function() {
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser.email+"&password="+sampleData.testUser.password);
        assert.equal(res.body.success, false);
    });
});

describe("Create User non-JSON API Tests", function() {
	before(function(){
		db.collection("users").remove();
	});

    it("should create a user", async function() {
        let res = await request.post(serverUrl + "/signup")
        	.send({
        		"email": sampleData.testUser.email,
        		"password": sampleData.testUser.password,
	        })

        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });


    it("should be able to confirm user with email-confirmation-token", async function() {
    	let user = await db.collection("users").find({ email: sampleData.testUser.email });
    	
        let res = await request.get(serverUrl + "/signup.json?email="+sampleData.testUser.email+"&password="+sampleData.testUser.password);
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
        		"email": sampleData.testUser.email,
        		"password": sampleData.testUser.password
        	}
        );        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

    it("not be able to create same user twice", async function() {
		let res = await request.post(serverUrl + "/signup", 
        	{
        		"email": sampleData.testUser.email,
        		"password": sampleData.testUser.password
        	}
        );      
        assert.equal(res.redirects[0], serverUrl + '/signup');  
    });


    it("should be able to confirm user's email", function(done){
        db.collection("users").findOne({
            "email": sampleData.testUser.email,
        }, async function(err, user){

            let res = await request.get(serverUrl + "/confirm-email?token=" + user.email_confirmation_token);
            assert.equal(res.redirects[0], serverUrl + '/');
            assert.equal(res.status, 200);

            let newUser = await db.collection("users").findOne({
                "email": sampleData.testUser.email,
            }, function(err, newUser){
                assert.ok(newUser.confirmed)
                done(err);
            })
        });

    });
});


describe("User Password Migration API Tests", function() {
    let salt = 'secret-the-cat';
    let oldPasswordHash = md5(sampleData.testUser.password + salt);

    before(function(){
        db.collection("users").remove();


        db.collection("users").insert({
            "email": sampleData.testUser.email,
            "password": oldPasswordHash,
            "confirmed": false,
            "email_confirmation_token": Math.random()
        });
    });


    it("should login as user", async function() {
        let res = await request.post(serverUrl + "/login", 
            {
                "email": sampleData.testUser.email,
                "password": sampleData.testUser.password
            }
        );        
        assert.equal(res.redirects[0], serverUrl + '/');
        assert.equal(res.status, 200);
    });

    it("should update password hash of user to bcrypt", function(done) {
        db.collection("users").findOne({
            "email": sampleData.testUser.email,
        }, function(err, user){
            assert.notEqual(user.password, oldPasswordHash);
            done(err);
        });
    });
});