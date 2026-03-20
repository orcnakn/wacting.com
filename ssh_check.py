import paramiko

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('37.148.212.121', username='root', password='Hd0#Yf3#Jb7#Xk2#', timeout=15)

def run(cmd):
    _, o, e = c.exec_command(cmd)
    out = o.read().decode(errors='replace').strip()
    err = e.read().decode(errors='replace').strip()
    print(out or err or '(empty)')

print('=== NODE_ENV on VDS ===')
run('pm2 env 0 2>&1 | grep -i "node_env\\|NODE_ENV"')

print('\n=== .env file on VDS ===')
run('cat /opt/wacting/wacting-server/.env 2>/dev/null')

print('\n=== main.dart.js contains PRODUCTION flag? ===')
run('grep -c "PRODUCTION" /var/www/wacting/main.dart.js 2>/dev/null')

print('\n=== Icon table count ===')
run('sudo -u postgres psql -d wacting_db -tAc \'SELECT COUNT(*) FROM "Icon";\' 2>/dev/null')

print('\n=== User table count ===')
run('sudo -u postgres psql -d wacting_db -tAc \'SELECT COUNT(*) FROM "User";\' 2>/dev/null')

print('\n=== Socket auth: does it require auth in production? ===')
run('grep -n "Authentication required\\|NODE_ENV" /opt/wacting/wacting-server/dist/socket/socket_manager.js 2>/dev/null | head -10')

c.close()
print('\nDone')
