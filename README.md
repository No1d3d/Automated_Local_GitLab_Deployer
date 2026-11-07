# Automated Local GitLab Deployer

Deploy GitLab CE in a rootful **Podman pod** on the local host, fully as code,
with the whole footprint **hard-capped at 30 GB**.

## What it does

`sudo make deploy` runs one idempotent Ansible playbook that:

1. Installs Podman if it is missing.
2. Creates a sparse 30 GB ext4 filesystem, loop-mounts it, and points Podman's
   storage root at it, so image + volumes + data can never exceed 30 GB.
3. Creates a Podman pod (`gitlab`) that publishes the HTTP/HTTPS/SSH ports and
   runs GitLab inside it, with data persisted on the capped filesystem.
4. Waits for the GitLab sign-in page, then prints the access URLs.

Re-running `sudo make deploy` reconciles the deployment.

## Requirements

- Linux host (Debian/Ubuntu or RHEL/Fedora); Podman is installed by the playbook.
- Ansible core >= 2.14 on the control host.
- root (the loop filesystem and rootful Podman need it). Run everything with
  `sudo`; this also avoids `become` issues on hosts that use sudo-rs.
- About 4 GB RAM free and at least 30 GB of disk.

Install the collections once:

```bash
make deps
```

## Quick start

```bash
# optional: set the root password from an encrypted vault
cp vars/vault.example.yml vars/vault.yml
ansible-vault encrypt vars/vault.yml

# deploy (first boot reconfigures GitLab: 5-15 min)
sudo make deploy

# check
sudo make status
```

Open **http://localhost** or **http://<host-ip>**. Git over SSH is
`ssh://git@<host-ip>:2222`. Log in as `root` with `vault_gitlab_root_password`;
without a vault, GitLab writes a generated password to
`<data>/config/initial_root_password`.

## Commands

| Command             | Action                                       |
|---------------------|----------------------------------------------|
| `make deps`         | Install the Ansible collections              |
| `make check`        | Syntax-check the playbooks                   |
| `sudo make deploy`  | Deploy or reconcile GitLab                   |
| `sudo make status`  | Pod/container state + 30 GB filesystem usage |
| `sudo make logs`    | Follow the GitLab container logs             |
| `sudo make shell`   | Shell inside the GitLab container            |
| `sudo make destroy` | Remove pod + container (keeps your data)     |

Pass extra Ansible flags with `ARGS`, e.g.
`sudo make deploy ARGS="--ask-vault-pass"`.

## Configuration

All settings live in `group_vars/all.yml`.

| Variable                 | Default                | Meaning                            |
|--------------------------|------------------------|------------------------------------|
| `gitlab_version`         | `19.5.3-ce.0`          | Pinned GitLab image tag            |
| `gitlab_edition`         | `ce`                   | `ce` or `ee`                       |
| `gitlab_http_port`       | `80`                   | Published HTTP port                |
| `gitlab_https_port`      | `443`                  | Published HTTPS port               |
| `gitlab_ssh_port`        | `2222`                 | Published Git-over-SSH port        |
| `gitlab_access_ip`       | auto-detected          | IP GitLab is reachable on          |
| `gitlab_storage_size_gb` | `30`                   | Hard cap of the GitLab footprint   |
| `gitlab_storage_mount`   | `/srv/gitlab-deployer` | Mountpoint of the 30 GB filesystem |

## The 30 GB cap

A sparse 30 GB ext4 image is loop-mounted at `gitlab_storage_mount`. Podman's
`graphroot` is redirected there and GitLab binds its `config/`, `logs/` and
`data/` there too, so the whole footprint is physically limited to 30 GB.

```bash
sudo make status   # df of the 30 GB filesystem
```

## Security

- The root password is never stored in the repo: set it through Ansible Vault
  (`vars/vault.yml`, git-ignored) and run with `--ask-vault-pass`.
- HTTP only, intended for a single trusted host; harden it before exposing it.

## Layout

```
ansible.cfg  requirements.yml  deploy.yml  destroy.yml  Makefile
inventory/hosts.yml         # localhost (connection: local)
group_vars/all.yml          # all configuration lives here
roles/gitlab_podman/
  tasks/{main,prerequisites,storage,deploy,health}.yml
  templates/gitlab-pod.service.j2
  defaults/main.yml  meta/main.yml
vars/vault.example.yml      # copy -> vars/vault.yml and encrypt
```
