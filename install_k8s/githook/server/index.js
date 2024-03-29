require('dotenv').config();
const express = require('express');
const app = express();
const bodyParser = require('body-parser');
const crypto = require('crypto');
const http = require('http');
const querystring = require('querystring');

//To parse URL encoded data
app.use(bodyParser.urlencoded({
  extended: false
}))
//To parse json data
app.use(bodyParser.json());
const SIGNATURE = 'x-hub-signature';

function verifyPostData(req, res, next) {
  const payload = JSON.stringify(req.body)

  if (!payload) {
    return next('Request body empty')
  }
  console.log(process.env.GITHUB_SECRET)
  const hmac = crypto.createHmac('sha1', process.env.GITHUB_SECRET);
  const digest = 'sha1=' + hmac.update(payload).digest('hex');

  const checksum = req.headers[SIGNATURE];

  if (!checksum || !digest || checksum !== digest) {
    return next(`Request body digest (${digest}) didnot match ${SIGNATURE} (${checksum})`)
  }

  return next();
}

function verifyLocalPostData(req, res, next) {
  const payload = JSON.stringify(req.body)

  if (!payload) {
    return next('Request body empty')
  }

   console.log(payload)
  return next();
}


app.get('/health', (req, res) => {
  console.log(req.body.toString('utf8'));
  res.send({
    Hi: 'Git Hook is up.'
  })
});

app.post('/localpayload', verifyLocalPostData, (req, res) => {

  var data = JSON.stringify(req.body);
  var options = {
    host: 'dockerhook.default.svc',
    port: 5002,
    method: 'POST',
    path: '/process',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    }
  };

  var httpreq = http.request(options, function(response) {
    response.setEncoding('utf8');
    response.on('data', function(chunk) {
      console.log("body: " + chunk);
    });
    response.on('end', function() {
      res.send('ok');
    })
  }).on("error", (err) => {
    console.log("Error: " + err.message);
  });
  httpreq.write(data);
  httpreq.end();
});




app.post('/payload', verifyPostData, (req, res) => {

  var data = JSON.stringify(req.body);
  var options = {
    host: 'dockerhook.default.svc',
    port: 5002,
    method: 'POST',
    path: '/process',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    }
  };

  var httpreq = http.request(options, function(response) {
    response.setEncoding('utf8');
    response.on('data', function(chunk) {
      console.log("body: " + chunk);
    });
    response.on('end', function() {
      res.send('ok');
    })
  }).on("error", (err) => {
    console.log("Error: " + err.message);
  });
  httpreq.write(data);
  httpreq.end();
});

app.use((err, req, res, next) => {
  console.log('In Error')
  console.log(err)
  res.status(403).send(err);
})

const PORT = process.env.PORT || 5001
app.listen(PORT);
