# Lab 2: secrets in git, encrypted to recipients

Starting point for Lab 2 (EPITA, Applied Cryptography). You will add encrypted secrets to this
repository with [SOPS](https://getsops.io/) and [age](https://age-encryption.org/), and make the
provided CI workflow decrypt them and deploy, **without leaking them**.

**Done when:** the `deploy` workflow passes on your own GitHub repository.

## What is provided

| File | What it does |
|---|---|
| `deploy.sh` | Decrypts `secrets/prod/database.yaml` with sops and "deploys" with those credentials |
| `.github/workflows/deploy.yml` | On every push to `main`: scans the files for secrets with betterleaks, then runs `deploy.sh` with the CI age key from the `SOPS_AGE_KEY` secret |
| `.gitignore` | Keeps every `*.key` file (age private keys) out of git |

What you add, following the lab slides: `.githooks/pre-commit` (betterleaks), `.sops.yaml`,
`secrets/prod/database.yaml`, `secrets/dev/database.yaml`, `SECRETS.md`.

## Before you start

1. Clone this repository, then push it to **your own private** GitHub repository: the workflow
   runs there, with your secrets.
   ```bash
   git clone git@github.com:zesk06/epita_crypto_lab_2.git && cd epita_crypto_lab_2
   git remote set-url origin git@github.com:<you>/<your-repo>.git
   git push -u origin main
   ```
2. Generate the age keys **inside this folder** (lab step 1). They are ignored by git.

## The file deploy.sh expects

`secrets/prod/database.yaml`, before encryption:

```yaml
postgres:
  user: postgres
  password: any value you like
```

The fake endpoint is `https://httpbin.org/basic-auth/USER/PASSWORD`, a public test service: it answers
200 only when called with exactly those credentials. So "deployment accepted" proves the secrets
were decrypted correctly. Nothing is really deployed.

## Run it locally

```bash
SOPS_AGE_KEY_FILE=alice.key ./deploy.sh                          # a prod recipient: accepted
SOPS_AGE_KEY_FILE=bob.key ./deploy.sh                            # bob is dev only: refused
SOPS_AGE_KEY_FILE=bob.key ./deploy.sh secrets/dev/database.yaml  # accepted
```

## Make the CI pass (lab step 5)

1. Create the CI identity: `age-keygen -o ci.key`.
2. Add its public key (`age-keygen -y ci.key`) to the **prod** rule of `.sops.yaml`, then re-key:
   `sops updatekeys secrets/prod/database.yaml`.
3. In your GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**,
   name `SOPS_AGE_KEY`, value: the `AGE-SECRET-KEY-...` line of `ci.key`.
4. Push. The scan step must find no leaks, the run must end with `deployment accepted (HTTP 200)`,
   and the log must never show the credentials.

## Things to try

- **Break it on purpose:** add `echo "$password"` to `deploy.sh` and push. GitHub masks the exact secret
  value in the log, but not `echo "$password" | base64`. Log masking is best-effort.
- **Who decrypted what, when?** With an age key in a CI secret, you cannot answer. A cloud KMS key can.
