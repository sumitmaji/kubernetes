require('dotenv').config();
const express = require('express');
const app = express();
const bodyParser = require('body-parser');
const crypto = require('crypto');
const shell = require('shelljs')
const Promise = require('bluebird')
const http = require('http');
//To parse URL encoded data
app.use(bodyParser.urlencoded({
  extended: false
}))
//To parse json data
app.use(bodyParser.json());

app.post('/process', (req, res, next) => {
  try {

    var url = req.body.repository.owner.html_url;
    var rep = req.body.repository.name;
    var ref = req.body.ref
    var branch = ref.split('/')[2]
    console.log(url, rep)
    execAsync(`./scripts/build.sh -r ${rep} -u ${url} -b ${branch}`, {
        silent: false,
        cwd: '.'
      })
      .then(stdout => {
        console.log('Success')
        submitDeploymentReq(url, rep, branch)
      })
      .catch(err => console.log(err));
    res.status(200).send('done');
  } catch (err) {
    next(err);
  }
});

function execAsync(cmd, opts = {}) {
  return new Promise(function(resolve, reject) {
    // Execute the command, reject if we exit non-zero (i.e. error)
    shell.exec(cmd, opts, function(code, stdout, stderr) {
      if (code != 0) return reject(new Error(stderr));
      return resolve(stdout);
    });
  });
}

app.get('/health', (req, res) => {
  console.log(req.body.toString('utf8'));
  res.send({
    Hi: 'Docker Hook is up.'
  })
});


function submitDeploymentReq(url, rep, branch){
  var data = JSON.stringify({
    payload: {
      url,
      rep,
      branch
    }
  });

  var options = {
     host: 'reghook.default.svc',
     port: 5003,
     method: 'POST',
     path: '/deploy',
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
       console.log('Deployment Request submitted.')
     })
   }).on("error", (err) => {
     console.log("Error: " + err.message);
   });
   httpreq.write(data);
   httpreq.end();
}

app.use((err, req, res, next) => {
  console.log(err)
  res.status(403).send(err);
})

const PORT = process.env.PORT || 5002
app.listen(PORT);
console.log(`Running on ${PORT}`);
