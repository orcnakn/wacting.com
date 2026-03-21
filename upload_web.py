import paramiko, os, sys, tarfile, io
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

local_dir = os.path.join('C:', os.sep, 'Users', 'STC', 'Desktop', 'wacting.com', 'wacting', 'build', 'web')

# Create tar.gz in memory
print('Creating tar.gz...')
tar_path = os.path.join('C:', os.sep, 'Users', 'STC', 'Desktop', 'wacting.com', 'web_build.tar.gz')
with tarfile.open(tar_path, 'w:gz') as tar:
    tar.add(local_dir, arcname='.')
size_mb = os.path.getsize(tar_path) / 1024 / 1024
print(f'Archive size: {size_mb:.1f} MB')

# Upload tar.gz
print('Uploading...')
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('37.148.212.121', username='root', password='Hd0#Yf3#Jb7#Xk2#', timeout=30)
sftp = c.open_sftp()
sftp.put(tar_path, '/tmp/web_build.tar.gz')
sftp.close()
print('Upload complete')

# Extract on server
print('Extracting on server...')
_, o, e = c.exec_command('cd /var/www/wacting && tar xzf /tmp/web_build.tar.gz && cp -rf /var/www/wacting/. /opt/wacting/wacting-server/dist/public/web/ && cp -rf /var/www/wacting/. /opt/wacting/wacting-server/src/public/web/ && rm /tmp/web_build.tar.gz && pm2 restart wacting-server && echo OK')
result = o.read().decode().strip()
err = e.read().decode().strip()
print(result or err)

c.close()
os.remove(tar_path)
print('Done')
