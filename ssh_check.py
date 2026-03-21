import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('37.148.212.121', username='root', password='Hd0#Yf3#Jb7#Xk2#', timeout=15)

def run(cmd):
    _, o, e = c.exec_command(cmd)
    print(o.read().decode(errors='replace').strip() or e.read().decode(errors='replace').strip() or '(empty)')

run('cd /opt/wacting && git fetch origin main && git reset --hard origin/main 2>&1 | tail -1')
run('cd /opt/wacting/wacting-server && npx prisma generate 2>&1 | tail -2')
run('cd /opt/wacting/wacting-server && npx prisma db push --accept-data-loss 2>&1 | tail -3')
run('cd /opt/wacting/wacting-server && npm run build 2>&1 | tail -2')
run('cp -rf /opt/wacting/wacting-server/dist/public/web/. /var/www/wacting/ && echo "Copied"')
run('pm2 restart wacting-server 2>&1 | grep "online"')
run('sleep 3 && curl -s http://localhost:3000/ping')

c.close()
print('Done')
