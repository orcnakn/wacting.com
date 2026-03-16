// SSH executor helper - runs a command on the VDS and returns output
const { Client } = require('ssh2');

const HOST = '37.148.212.121';
const USER = 'root';
const PASS = 'Hd0#Yf3#Jb7#Xk2#';

function sshExec(cmd, timeout = 120000) {
  return new Promise((resolve, reject) => {
    const conn = new Client();
    let output = '';
    const timer = setTimeout(() => {
      conn.end();
      resolve(output + '\n[TIMEOUT]');
    }, timeout);

    conn.on('ready', () => {
      conn.exec(cmd, { pty: false }, (err, stream) => {
        if (err) { clearTimeout(timer); conn.end(); reject(err); return; }
        stream.on('data', d => { output += d.toString(); process.stdout.write(d.toString()); });
        stream.stderr.on('data', d => { output += d.toString(); process.stderr.write(d.toString()); });
        stream.on('close', (code) => {
          clearTimeout(timer);
          conn.end();
          resolve(output);
        });
      });
    }).on('error', e => {
      clearTimeout(timer);
      reject(e);
    }).connect({ host: HOST, port: 22, username: USER, password: PASS });
  });
}

// Run command from argv
const cmd = process.argv[2];
if (!cmd) { console.error('Usage: node ssh_exec.js "command"'); process.exit(1); }

sshExec(cmd, parseInt(process.argv[3]) || 120000)
  .then(() => process.exit(0))
  .catch(e => { console.error('ERROR:', e.message); process.exit(1); });
