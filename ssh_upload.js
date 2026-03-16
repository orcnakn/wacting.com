const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const HOST = '37.148.212.121';
const USER = 'root';
const PASS = 'Hd0#Yf3#Jb7#Xk2#';

const localPath = process.argv[2];
const remotePath = process.argv[3];

if (!localPath || !remotePath) {
  console.error('Usage: node ssh_upload.js <local> <remote>');
  process.exit(1);
}

const conn = new Client();
conn.on('ready', () => {
  conn.sftp((err, sftp) => {
    if (err) { console.error('SFTP error:', err); process.exit(1); }
    const rs = fs.createReadStream(localPath);
    const ws = sftp.createWriteStream(remotePath);
    ws.on('close', () => {
      console.log('Upload complete:', remotePath);
      conn.end();
    });
    ws.on('error', (e) => { console.error('Write error:', e); conn.end(); process.exit(1); });
    rs.pipe(ws);
  });
}).on('error', (e) => {
  console.error('SSH error:', e.message);
  process.exit(1);
}).connect({ host: HOST, port: 22, username: USER, password: PASS });
