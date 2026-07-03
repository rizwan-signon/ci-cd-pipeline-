# Practice Project: Dockerize + CI/CD + Deploy to a VM

A deliberately tiny full-stack app whose only job is to teach you the full
flow: **code → Docker → GitHub → CI/CD → VM**.

- `be/` — a 20-line Express API (`GET /api/hello`)
- `fe/` — a single static HTML page that calls the API
- Each has its **own Dockerfile** (as you already have)
- `docker-compose.yml` — run both together locally
- `.github/workflows/deploy.yml` — builds images, pushes to Docker Hub, SSHs
  into your VM, and redeploys — automatically on every push to `main`

There is intentionally no framework, no build step, no database. Once this
flow feels boring and obvious, swap in your real apps.

---

## The big picture

```
 You push code to GitHub (main branch)
              │
              ▼
   GitHub Actions runner starts
              │
   ┌──────────┴───────────┐
   │  1. docker build      │  builds be/ and fe/ images
   │  2. docker push       │  pushes them to Docker Hub
   └──────────┬───────────┘
              │
   ┌──────────┴───────────┐
   │  3. scp compose file  │  copies docker-compose.prod.yml to the VM
   │  4. ssh into the VM   │  runs `docker compose pull && up -d`
   └──────────┬───────────┘
              │
              ▼
      Your VM is now running
      the new containers
```

Docker Hub is the handoff point: GitHub Actions never sends files/code
straight to the VM (other than the tiny compose file) — it pushes an
**image**, and the VM just pulls that image and runs it. That's the part
that makes this "production-like" instead of a hacky `scp` + `npm start`.

---

## Part 1 — Run it locally first

```bash
docker compose up --build
```

- Frontend: http://localhost
- Backend directly: http://localhost:5000/api/hello

The frontend's nginx config proxies `/api/*` to the `be` container using
Docker's internal DNS (service name `be`) — that's why the JS in
`fe/index.html` just calls `fetch('/api/hello')` with no hostname.

Get comfortable with this loop before touching CI/CD:
- change `be/server.js`, rerun `docker compose up --build`, refresh the page
- `docker compose logs -f`
- `docker compose down`

---

## Part 2 — Push to GitHub

```bash
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

(Don't push yet if you haven't set up secrets — the workflow will just fail
loudly and harmlessly, so it's fine either way, but let's set up secrets
first so the first run actually succeeds.)

---

## Part 3 — Create a Docker Hub account + access token

1. Sign up at hub.docker.com (free)
2. Account Settings → Security → **New Access Token** → copy it (you won't
   see it again)

---

## Part 4 — Spin up the VM

Any small VM works (DigitalOcean droplet, AWS EC2, Oracle free tier, etc).
Ubuntu 22.04/24.04, smallest size is plenty.

SSH in and run the setup script once:

```bash
scp deploy/setup-vm.sh youruser@your-vm-ip:~
ssh youruser@your-vm-ip
bash setup-vm.sh
```

This installs Docker + the Compose plugin and creates `~/practice-app`,
which is where the pipeline will drop `docker-compose.prod.yml`.

Then create the env file the compose file needs:

```bash
echo "DOCKERHUB_USERNAME=your-dockerhub-username" > ~/practice-app/.env
```

Also make sure ports 80 and 5000 are open in your cloud provider's
firewall/security group (not just the OS firewall).

---

## Part 5 — Generate an SSH key for GitHub Actions

GitHub Actions needs its **own** key pair to SSH into the VM (don't reuse
your personal one).

```bash
ssh-keygen -t ed25519 -f deploy_key -N ""
```

- Add `deploy_key.pub` to the VM: `ssh-copy-id -i deploy_key.pub youruser@your-vm-ip`
  (or manually append it to `~/.ssh/authorized_keys` on the VM)
- Keep `deploy_key` (the private key) — you'll paste it into GitHub next

---

## Part 6 — Add GitHub Secrets

In your GitHub repo: **Settings → Secrets and variables → Actions → New
repository secret**. Add:

| Secret name           | Value                                      |
|------------------------|---------------------------------------------|
| `DOCKERHUB_USERNAME`   | your Docker Hub username                    |
| `DOCKERHUB_TOKEN`      | the access token from Part 3                |
| `VM_HOST`              | your VM's IP address                        |
| `VM_USER`              | the SSH user on the VM                      |
| `VM_SSH_KEY`           | full contents of the **private** `deploy_key` file |

---

## Part 7 — Trigger the pipeline

```bash
git add .
git commit -m "trigger pipeline"
git push
```

Watch it run under the **Actions** tab in GitHub. If it goes green, visit
`http://your-vm-ip` in a browser — you should see the page calling the
backend and getting back a JSON blob with a timestamp.

---

## What to break/change next (this is how you actually learn it)

1. Change the message in `be/server.js`, push, watch the new version show
   up on the VM automatically.
2. Look at `docker-compose.prod.yml` vs `docker-compose.yml` — notice one
   builds from source, the other pulls a published image. That distinction
   (build locally vs. ship a built artifact) is the core idea of CI/CD.
3. Add a second backend route and call it from the frontend.
4. Add environment variables (e.g. an API key) and pass them through
   `docker-compose.prod.yml` and GitHub Secrets instead of hardcoding them.
5. Try tagging images with the Git commit SHA instead of `latest`, so you
   can roll back to a specific previous version.
6. Add a staging environment: a second VM + a second workflow triggered on
   a `staging` branch.

## Troubleshooting

- **Workflow fails at docker login** → check `DOCKERHUB_USERNAME` /
  `DOCKERHUB_TOKEN` secrets are exactly right (token, not your Docker Hub
  password).
- **SSH step fails** → confirm the public key is in
  `~/.ssh/authorized_keys` on the VM for the exact `VM_USER`, and that
  `VM_SSH_KEY` secret is the full private key including the
  `-----BEGIN...-----` / `-----END...-----` lines.
- **Site loads but `/api/hello` fails** → `ssh` into the VM and run
  `docker compose -f docker-compose.prod.yml logs` to see container logs.
- **Can't reach the VM at all in a browser** → it's almost always the cloud
  provider's firewall/security group, not the OS-level one.
