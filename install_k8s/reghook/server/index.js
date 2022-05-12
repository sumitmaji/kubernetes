require('dotenv').config();
const express = require('express');
const app = express();
const bodyParser = require('body-parser');
const crypto = require('crypto');
const shell = require('shelljs')

//To parse URL encoded data
app.use(bodyParser.urlencoded({
  extended: false
}))
//To parse vnd.docker.distribution.events.v1+json data
app.use(bodyParser.raw({
  // type: 'application/vnd.docker.distribution.events.v1+json'
  type: 'application/json'
}));
// app.use(bodyParser.json());
app.use(function(req, res, next) {
  var data = '';
  req.setEncoding('utf8');
  req.on('data', function(chunk) {
    data += chunk;
  });
  req.on('end', function() {
    req.rawBody = data;
  });
  next();
});

app.post('/event', (req, res) => {
  console.log(req.body.toString('utf8'));
  res.send({
    Hi: 'There'
  })
});

app.post('/deploy', (req, res) => {
  var data = JSON.parse(req.body.toString('utf8'));
  var {
    url,
    rep,
    branch
  } = data.payload
  execAsync(`./scripts/build.sh -r ${rep} -u ${url} -b ${branch}`, {
      silent: false,
      cwd: '.'
    })
    .then(stdout => {
      console.log('Success')
    })
    .catch(err => console.log(err));
  res.send('ok')
});

app.use((err, req, res, next) => {
  console.log(err);
  res.status(403).send(err);
})


function execAsync(cmd, opts = {}) {
  return new Promise(function(resolve, reject) {
    // Execute the command, reject if we exit non-zero (i.e. error)
    shell.exec(cmd, opts, function(code, stdout, stderr) {
      if (code != 0) return reject(new Error(stderr));
      return resolve(stdout);
    });
  });
}

const PORT = process.env.PORT || 5003
app.listen(PORT);
