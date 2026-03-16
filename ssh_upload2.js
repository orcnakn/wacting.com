// Upload file via SSH by piping stdin to remote cat
const { Client } = require('ssh2');
const fs = require('fs');

const HOST = '37.148.212.121';
const USER = 'root';
const PASS = 'Hd0#Yf3#Jb7#Xk2#';

const localPath = process.argv[2];
const remotePath = process.argv[3];

if (!localPath || !remotePath) {
  console.error('Usage: node ssh_upload2.js <local> <remote>');
  process.exit(1);
}

const conn = new Client();
conn.on('ready', () => {
  conn.exec(`cat > ${remotePath}`, (err, stream) => {
    if (err) { console.error('Exec error:', err); conn.end(); process.exit(1); }
    stream.on('close', (code) => {
      console.log(`Upload complete (exit ${code}): ${remotePath}`);
      conn.end();
    });
    const rs = fs.createReadStream(localPath);
    rs.pipe(stream.stdin);
  });
}).on('error', (e) => {
  console.error('SSH error:', e.message);
  process.exit(1);
}).connect({ host: HOST, port: 22, username: USER, password: PASS });
