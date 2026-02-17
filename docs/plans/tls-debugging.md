# TLS Debugging Plan for bonanza2.fh-potsdam.de

Caddy cannot obtain Let's Encrypt certificates. Both HTTP-01 and TLS-ALPN-01
challenges time out with "Timeout during connect (likely firewall problem)".

## Phase 1: Confirm current state on the server

### Step 1 — Check what's listening on ports 80 and 443

```bash
sudo ss -tlnp | grep -E ':80|:443'
```

- **Good:** Lines showing Docker proxy or Caddy listening on `0.0.0.0:80` and `0.0.0.0:443`
- **Bad:** Nothing listening, or only `127.0.0.1`

### Step 2 — Check Docker container port mappings

```bash
docker compose -f docker-compose.yml ps
```

- **Good:** Caddy with `0.0.0.0:80->80/tcp` and `0.0.0.0:443->443/tcp`
- **Bad:** Shows `8080->8080` means override is being merged. Use `-f docker-compose.yml` explicitly.

### Step 3 — Check what CADDY_ADDRESS resolves to

```bash
grep CADDY_ADDRESS .env
```

Must be the bare domain (`bonanza2.fh-potsdam.de`) for auto-HTTPS.

## Phase 2: Check the local firewall

### Step 4 — Check UFW status

```bash
sudo ufw status verbose
```

- If active, check for 80/443 allow rules. If missing:
  ```bash
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  ```
- If inactive, move on.

### Step 5 — Check iptables rules

```bash
sudo iptables -L -n -v | head -60
sudo iptables -L INPUT -n -v
sudo iptables -L DOCKER-USER -n -v 2>/dev/null
```

- Look for DROP/REJECT rules for port 80/443
- Check `DOCKER-USER` chain — blanket DROP here blocks Docker-published ports

### Step 6 — Check nftables

```bash
sudo nft list ruleset 2>/dev/null | head -80
```

## Phase 3: Test reachability

### Step 7 — Test locally on the server

```bash
curl -v http://localhost:80/ 2>&1 | head -20
curl -v -k https://localhost:443/ 2>&1 | head -20
```

Confirms Caddy is listening.

### Step 8 — Test from outside (run from Fabian's machine, NOT the server)

```bash
curl -v --connect-timeout 10 http://bonanza2.fh-potsdam.de/ 2>&1 | head -20
curl -v --connect-timeout 10 -k https://bonanza2.fh-potsdam.de/ 2>&1 | head -20
```

- **Good:** Any response
- **Bad:** "Connection timed out" = network firewall blocking inbound

### Step 9 — Raw TCP test (from Fabian's machine)

```bash
nc -zv -w 5 bonanza2.fh-potsdam.de 80
nc -zv -w 5 bonanza2.fh-potsdam.de 443
nc -zv -w 5 bonanza2.fh-potsdam.de 22
```

If SSH (22) works but 80/443 don't, a selective firewall is confirmed.

## Phase 4: Investigate old setup

### Step 10 — Check old certbot certs

```bash
sudo ls -la /etc/letsencrypt/live/
sudo cat /etc/letsencrypt/renewal/*.conf
```

Is the cert for `bonanza.fh-potsdam.de` or `bonanza2.fh-potsdam.de`?

### Step 11 — Check cert details

```bash
sudo openssl x509 -in /etc/letsencrypt/live/*/fullchain.pem -noout -subject -issuer -dates -ext subjectAltName
```

### Step 12 — Check certbot renewal history

```bash
sudo cat /var/log/letsencrypt/letsencrypt.log 2>/dev/null | tail -50
```

Shows when certbot last renewed successfully. If recent, the firewall was
open at some point.

## Phase 5: DNS verification

### Step 13 — Verify DNS from outside (from Fabian's machine)

```bash
dig bonanza2.fh-potsdam.de A +short
dig bonanza2.fh-potsdam.de AAAA +short
```

Should return `194.94.235.206`.

### Step 14 — Check for split-horizon DNS (on the server)

```bash
dig bonanza2.fh-potsdam.de A +short
dig bonanza2.fh-potsdam.de A +short @8.8.8.8
```

Different answers = split-horizon DNS. Let's Encrypt queries from outside.

## Phase 6: Check for NAT

### Step 15 — Check the server's own IP

```bash
ip addr show | grep 'inet '
hostname -I
```

- If `194.94.235.206` appears: server has a public IP
- If private IP (`10.x`, `172.16.x`, `192.168.x`): behind NAT, port forwarding needed

## Diagnosis and path forward

### Scenario A: University firewall blocking ports 80/443 (most likely)

Contact FHP IT:

> "Please open inbound TCP ports 80 and 443 from the public internet to
> 194.94.235.206 (bonanza2.fh-potsdam.de). This is needed for Let's Encrypt
> ACME HTTP-01 certificate validation and for serving HTTPS traffic."

### Scenario B: Ports open but something else wrong

Re-examine Caddy logs, Docker networking, port conflicts.

### Scenario C: Ports will never be opened (university policy)

Alternatives:

1. **DNS-01 challenge** — Needs TXT record access for
   `_acme-challenge.bonanza2.fh-potsdam.de`. Ask FHP IT to delegate or
   manage records. Caddy needs a custom build with DNS provider plugin.

2. **Mount existing certbot certs into Caddy** — Only if cert covers
   `bonanza2.fh-potsdam.de` and certbot can still renew.

3. **University-provided certificate** — FH Potsdam may have institutional
   certs via DFN/GEANT TCS. Mount into Caddy.

4. **Edge reverse proxy** — FHP terminates TLS at network edge, forwards
   plain HTTP to the server. Caddy runs on `:80`.

## After fixing: retry ACME

Rate limits reset after 1 hour. Then:

```bash
docker compose down
docker volume rm $(docker volume ls -q | grep caddy_data)
docker compose up -d
docker compose logs -f caddy
```
