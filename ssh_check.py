import paramiko, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect('37.148.212.121', username='root', password='Hd0#Yf3#Jb7#Xk2#', timeout=15)

def run(cmd, timeout=60):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    out = o.read().decode(errors='replace').strip()
    err = e.read().decode(errors='replace').strip()
    print(out or err or '(empty)')

print('=== 5. copy flutter + restart ===')
run('cp -rf /opt/wacting/wacting-server/dist/public/web/. /var/www/wacting/ && echo "Copied"')
run('pm2 restart wacting-server 2>&1 | tail -5')

print('\n=== 6. nginx reload ===')
run('nginx -t 2>&1 && systemctl reload nginx && echo "Nginx OK"')

print('\n=== 7. verify ===')
run('sleep 3 && curl -s http://localhost:3000/ping 2>&1')

c.close()
print('\nDone')
