# Gitea Actions Workflow Examples

This directory contains practical, production-ready workflow examples for Gitea Actions. These workflows are compatible with GitHub Actions syntax and optimized for ARM64 (Raspberry Pi 5).

## Available Workflows

| Workflow | Description | Use Case |
|----------|-------------|----------|
| [hello-world.yml](./hello-world.yml) | Basic workflow test | Verify Gitea Actions is working |
| [nodejs-app.yml](./nodejs-app.yml) | Node.js build & test | CI/CD for Node.js applications |
| [docker-build.yml](./docker-build.yml) | Docker build & push | Build and deploy Docker images |
| [supabase-edge-function.yml](./supabase-edge-function.yml) | Deploy Supabase functions | Auto-deploy edge functions |
| [backup-to-rclone.yml](./backup-to-rclone.yml) | Scheduled backups | Backup repositories to cloud storage |

## Quick Start

### 1. Copy Workflows to Your Repository

Gitea Actions looks for workflows in `.gitea/workflows/` directory (or `.github/workflows/` for GitHub compatibility).

```bash
# Create the workflows directory
mkdir -p .gitea/workflows

# Copy a workflow example
cp hello-world.yml /path/to/your/repo/.gitea/workflows/

# Commit and push
cd /path/to/your/repo
git add .gitea/workflows/hello-world.yml
git commit -m "Add Gitea Actions workflow"
git push
```

### 2. Configure Secrets

Many workflows require secrets (API keys, tokens, passwords). Configure them in Gitea:

**Via Web UI:**
1. Go to your repository in Gitea
2. Click **Settings** → **Secrets**
3. Click **Add Secret**
4. Enter the secret name and value
5. Click **Add**

**Via API:**
```bash
curl -X POST "https://gitea.yourdomain.com/api/v1/repos/{owner}/{repo}/secrets" \
  -H "Authorization: token YOUR_GITEA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MY_SECRET",
    "data": "secret_value"
  }'
```

### 3. Set Up Gitea Actions Runner

Ensure you have at least one Gitea Actions runner registered. See the main Gitea documentation for runner setup.

```bash
# Check if runners are available
# Go to Repository → Settings → Actions → Runners
```

## Workflow Configuration

### Common Secrets Required

#### For Docker Workflows
- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub password or access token
- `GITEA_TOKEN` - Gitea access token (for Gitea container registry)

#### For Supabase Workflows
- `SUPABASE_ACCESS_TOKEN` - Supabase access token
- `SUPABASE_PROJECT_ID` - Supabase project ID
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key

#### For Backup Workflows
- `RCLONE_CONFIG` - Complete rclone configuration file
- `R2_ACCESS_KEY_ID` - Cloudflare R2 access key
- `R2_SECRET_ACCESS_KEY` - Cloudflare R2 secret key
- `R2_ACCOUNT_ID` - Cloudflare R2 account ID

#### For Notifications
- `DISCORD_WEBHOOK_URL` - Discord webhook URL
- `SLACK_WEBHOOK_URL` - Slack webhook URL
- `NTFY_TOPIC` - ntfy.sh topic (can be a variable instead)
- `GOTIFY_URL` - Gotify server URL
- `GOTIFY_TOKEN` - Gotify application token

### Using Variables (Non-Secret Configuration)

For non-sensitive configuration, use repository variables:

1. Go to **Settings** → **Variables**
2. Add variables like `NTFY_TOPIC`, `DEPLOY_ENV`, etc.
3. Access in workflows: `${{ vars.VARIABLE_NAME }}`

## Workflow Triggers

### Push Events
```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'src/**'
    tags:
      - 'v*.*.*'
```

### Pull Request Events
```yaml
on:
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize
      - reopened
```

### Scheduled Events (Cron)
```yaml
on:
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'
    # Run every Monday at 9 AM UTC
    - cron: '0 9 * * 1'
```

### Manual Trigger
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - production
          - staging
        default: staging
```

### Combined Triggers
```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:
```

## Context Variables

Access workflow context using `${{ }}` syntax:

### GitHub Context (works in Gitea too)
```yaml
${{ github.repository }}      # owner/repo-name
${{ github.ref }}              # refs/heads/main
${{ github.ref_name }}         # main
${{ github.sha }}              # commit SHA
${{ github.actor }}            # username who triggered workflow
${{ github.event_name }}       # push, pull_request, etc.
${{ github.workspace }}        # workspace directory path
${{ github.server_url }}       # Gitea server URL
```

### Runner Context
```yaml
${{ runner.os }}               # Linux, macOS, Windows
${{ runner.arch }}             # X64, ARM64, etc.
${{ runner.name }}             # Runner name
${{ runner.temp }}             # Temp directory
```

### Secrets and Variables
```yaml
${{ secrets.MY_SECRET }}       # Access secret
${{ vars.MY_VARIABLE }}        # Access variable
```

### Job Context
```yaml
${{ job.status }}              # success, failure, cancelled
${{ needs.job_id.result }}     # Result of dependent job
${{ needs.job_id.outputs.var }} # Output from dependent job
```

## Gitea Actions vs GitHub Actions

### Compatibility
Gitea Actions is designed to be compatible with GitHub Actions syntax. Most GitHub Actions workflows work in Gitea with minimal or no changes.

### Key Differences

| Feature | GitHub Actions | Gitea Actions |
|---------|---------------|---------------|
| Workflow location | `.github/workflows/` | `.gitea/workflows/` or `.github/workflows/` |
| Hosted runners | Available | Self-hosted only |
| Actions marketplace | GitHub marketplace | Use any GitHub action |
| Billing | Paid (limited free) | Free (self-hosted) |
| ARM64 support | Limited | Native (Pi 5) |

### Actions Compatibility

Most GitHub Actions work in Gitea:
```yaml
# These work in both GitHub and Gitea
- uses: actions/checkout@v4
- uses: actions/setup-node@v4
- uses: actions/cache@v4
- uses: docker/build-push-action@v5
```

### Known Limitations

1. **Artifacts**: Some artifact actions may not work identically
2. **OIDC**: GitHub's OIDC features not available
3. **Environments**: GitHub Environments feature not supported
4. **Deployment protection rules**: Not available in Gitea

### Best Practices for Compatibility

1. **Use `continue-on-error: true`** for features that might not be available
2. **Test locally first** using [act](https://github.com/nektos/act)
3. **Use conditional steps** to handle differences:
   ```yaml
   - name: GitHub-specific step
     if: github.server_url == 'https://github.com'
     run: echo "Running on GitHub"
   ```

## ARM64 / Raspberry Pi 5 Considerations

### Multi-Architecture Builds

When building Docker images for Pi 5, specify platform:
```yaml
- uses: docker/build-push-action@v5
  with:
    platforms: linux/arm64,linux/amd64
```

### ARM64-Specific Packages

Some tools need ARM64 versions:
```bash
# Download ARM64 version
curl -fsSL https://example.com/tool_linux_arm64.tar.gz | tar -xz

# Check architecture
uname -m  # Should show aarch64
```

### Performance Tips

1. **Use caching aggressively** - ARM64 builds can be slower
2. **Parallelize when possible** - Use matrix builds
3. **Pre-build dependencies** - Create base images with dependencies

## Caching Strategies

### NPM Cache
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

### Docker Layer Cache
```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Custom Cache
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache
      vendor/
    key: ${{ runner.os }}-${{ hashFiles('**/go.sum') }}
    restore-keys: |
      ${{ runner.os }}-
```

## Error Handling

### Continue on Error
```yaml
- name: Optional Step
  run: npm run lint
  continue-on-error: true
```

### Conditional Execution
```yaml
- name: Only on Success
  if: success()
  run: echo "Previous steps succeeded"

- name: Only on Failure
  if: failure()
  run: echo "A step failed"

- name: Always Run
  if: always()
  run: echo "Runs regardless of status"
```

### Timeout
```yaml
jobs:
  build:
    timeout-minutes: 30
    steps:
      - name: Long Running Step
        timeout-minutes: 10
        run: ./long-script.sh
```

## Troubleshooting

### Workflow Not Running

1. **Check workflow syntax**
   ```bash
   # Use yamllint to validate
   yamllint .gitea/workflows/*.yml
   ```

2. **Verify triggers match your push**
   - Check branch names
   - Check path filters
   - Review event types

3. **Check runner availability**
   - Go to Settings → Actions → Runners
   - Ensure at least one runner is online

### Workflow Fails

1. **Check logs** in Gitea UI under Actions tab

2. **Common issues:**
   - Missing secrets
   - Wrong permissions
   - Unavailable actions
   - Network issues

3. **Debug with verbose output:**
   ```yaml
   - name: Debug
     run: |
       set -x  # Enable verbose mode
       echo "Debugging..."
       env | sort
   ```

### Secrets Not Working

1. **Verify secret is set** in repository settings
2. **Check secret name** matches exactly (case-sensitive)
3. **Secrets are not available in forked repos** by default

### Actions Not Found

If a GitHub action fails to download:
```yaml
# Use alternative registry
- uses: https://github.com/actions/checkout@v4
```

## Testing Workflows Locally

Use [act](https://github.com/nektos/act) to test workflows locally:

```bash
# Install act
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow locally
act push

# Run specific job
act -j build

# Use secrets file
act --secret-file .secrets

# Dry run
act -n
```

## Security Best Practices

### 1. Never Commit Secrets
```bash
# Add to .gitignore
echo ".secrets" >> .gitignore
echo "*.env" >> .gitignore
```

### 2. Use Secrets for Sensitive Data
```yaml
# ✗ Bad
env:
  API_KEY: "sk_live_123456789"

# ✓ Good
env:
  API_KEY: ${{ secrets.API_KEY }}
```

### 3. Limit Secret Scope
- Use repository secrets for repo-specific values
- Use organization secrets for shared values
- Use environment secrets for environment-specific values

### 4. Rotate Secrets Regularly
```bash
# Rotate every 90 days
# Document rotation date in secret description
```

### 5. Use Read-Only Tokens When Possible
```yaml
# Use tokens with minimal required permissions
permissions:
  contents: read
  packages: write
```

### 6. Pin Action Versions
```yaml
# ✗ Bad - uses latest, might break
- uses: actions/checkout@main

# ✓ Good - pinned to specific version
- uses: actions/checkout@v4

# ✓ Better - pinned to specific commit SHA
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
```

## Advanced Patterns

### Matrix Builds
```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, self-hosted]
    include:
      - node-version: 18
        experimental: true
    exclude:
      - node-version: 22
        os: self-hosted
```

### Reusable Workflows
```yaml
# .gitea/workflows/reusable.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      token:
        required: true

# Call from another workflow
jobs:
  call-workflow:
    uses: ./.gitea/workflows/reusable.yml
    with:
      environment: production
    secrets:
      token: ${{ secrets.TOKEN }}
```

### Composite Actions
```yaml
# .gitea/actions/setup/action.yml
name: 'Setup'
description: 'Setup build environment'
runs:
  using: "composite"
  steps:
    - run: echo "Setting up..."
      shell: bash
```

### Job Outputs
```yaml
jobs:
  build:
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - id: version
        run: echo "version=1.0.0" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    steps:
      - run: echo "Deploying ${{ needs.build.outputs.version }}"
```

## Resources

### Documentation
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [GitHub Actions Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [act - Local Testing](https://github.com/nektos/act)

### Example Repositories
- [Gitea Actions Examples](https://github.com/go-gitea/gitea/tree/main/.github/workflows)
- [Awesome Actions](https://github.com/sdras/awesome-actions)

### Tools
- [yamllint](https://github.com/adrienverge/yamllint) - YAML validation
- [actionlint](https://github.com/rhysd/actionlint) - Workflow validation
- [act](https://github.com/nektos/act) - Local workflow testing

## Contributing

Have a useful workflow example? Contributions are welcome!

1. Create a new workflow file with clear comments
2. Test it thoroughly
3. Document required secrets and variables
4. Add it to the table in this README
5. Submit a pull request

## License

These workflow examples are provided as-is for use in your projects. Feel free to modify and adapt them to your needs.
