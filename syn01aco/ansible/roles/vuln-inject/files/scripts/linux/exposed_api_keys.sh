#!/bin/bash
# vuln: exposed_api_keys | severity: high
echo "[VULN] Injecting Exposed API Keys in environment..."
cat >> /etc/environment << 'EOFTXT'
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
GITHUB_TOKEN=ghp_abc123xyz789secrettoken
DATABASE_URL=mysql://root:Admin@123@10.0.20.30/cyber_range
EOFTXT
cat > /opt/.env << 'EOFTXT'
SECRET_KEY=django-insecure-abc123xyz789
DATABASE_URL=mysql://root:Admin@123@10.0.20.30/cyber_range
REDIS_URL=redis://:password@localhost:6379/0
EOFTXT
chmod 644 /opt/.env
echo "[VULN] API keys exposed in /etc/environment and /opt/.env"
