HOW TO ADD A WEBSITE
====================
1. Create a folder here named after your site, e.g.  sites/my-site/
2. Put your index.html (static) or index.php (PHP) and other files inside
3. Open  ../../group_vars/web_servers.yml  and add an entry:
       - name: my-site
         port: 8004
         php: true
4. Re-run:  ansible-playbook site.yml --limit web_servers

The site will be live at  http://<web-server-ip>:8004
