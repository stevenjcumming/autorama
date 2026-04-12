# Justification Categories

This document provides examples of justification categories and questions you can configure in `.claude/autocode.yml`.

## Default Categories

These categories are included in the default `autocode.yml` template:

- `spec_modification`
- `migration`
- `dependency`
- `configuration`
- `security`

Run `/autocode:init` to copy the default template to `.claude/autocode.yml`, or manually copy from the plugin's `templates/autocode.yml`. Modify the file's patterns or questions to fit your project's needs.

---

## Additional Category Examples

Add these to your `.claude/autocode.yml` under `justification.categories`:

### Infrastructure / DevOps

```yaml
infrastructure:
  title: "Infrastructure Change"
  patterns:
    - "terraform/**"
    - "*.tf"
    - "*.tfvars"
    - "k8s/**"
    - "helm/**"
    - "docker-compose*.yml"
    - "Dockerfile*"
  questions:
    - "Has the platform team reviewed this?"
    - "What environments are affected?"
    - "Is this change reversible?"
    - "Have you tested in staging first?"
```

### CI/CD Pipeline

```yaml
cicd:
  title: "CI/CD Pipeline Change"
  patterns:
    - ".github/workflows/*"
    - ".gitlab-ci.yml"
    - "Jenkinsfile"
    - ".circleci/*"
    - "azure-pipelines.yml"
  questions:
    - "Does this affect build times?"
    - "Are there new secrets or credentials needed?"
    - "Could this break deployments?"
    - "Have you tested the pipeline locally?"
```

### Database Schema

```yaml
schema:
  title: "Database Schema Change"
  patterns:
    - "*/schema.rb"
    - "*/structure.sql"
    - "prisma/schema.prisma"
    - "*.sql"
  questions:
    - "Is this backwards compatible?"
    - "Does this require a data migration?"
    - "What is the impact on existing data?"
    - "Has DBA reviewed for performance implications?"
```

### Feature Flags

```yaml
feature_flags:
  title: "Feature Flag Modification"
  patterns:
    - "*feature_flag*"
    - "*feature_toggle*"
    - "*flipper*"
    - "*launch_darkly*"
  questions:
    - "Is this enabling or disabling a flag?"
    - "What percentage of users are affected?"
    - "Is there a rollback plan?"
    - "Has product approved this change?"
```

### Payment / Billing

```yaml
payments:
  title: "Payment/Billing Code"
  patterns:
    - "*payment*"
    - "*billing*"
    - "*invoice*"
    - "*subscription*"
    - "*stripe*"
    - "*braintree*"
  questions:
    - "Does this affect how customers are charged?"
    - "Has finance reviewed pricing changes?"
    - "Is PCI compliance maintained?"
    - "Have you tested with sandbox/test mode?"
```

### Internationalization

```yaml
i18n:
  title: "Internationalization Change"
  patterns:
    - "*/locales/*"
    - "*/translations/*"
    - "*.po"
    - "*.pot"
    - "*i18n*"
  questions:
    - "Are all supported languages updated?"
    - "Are there new strings that need translation?"
    - "Has copy been reviewed by content team?"
```

### Third-Party Integrations

```yaml
integrations:
  title: "Third-Party Integration"
  patterns:
    - "**/integrations/*"
    - "**/vendors/*"
    - "**/external/*"
    - "*_client.rb"
    - "*Client.ts"
  questions:
    - "Does the third party have SLA guarantees?"
    - "Is there a fallback if the service is down?"
    - "Are API rate limits handled?"
    - "Is there proper error handling for API failures?"
```

### Background Jobs

```yaml
jobs:
  title: "Background Job Change"
  patterns:
    - "**/jobs/*"
    - "**/workers/*"
    - "*_job.rb"
    - "*_worker.rb"
    - "*Job.ts"
    - "*Worker.ts"
  questions:
    - "Is this job idempotent?"
    - "What happens if the job fails mid-execution?"
    - "Is there proper retry logic?"
    - "Could this overwhelm downstream services?"
```

### Caching

```yaml
caching:
  title: "Cache Configuration"
  patterns:
    - "*cache*"
    - "*redis*"
    - "*memcache*"
  questions:
    - "What is the cache invalidation strategy?"
    - "Could stale data cause issues?"
    - "What is the TTL and is it appropriate?"
    - "Is there a cache warming strategy?"
```

### Logging / Monitoring

```yaml
observability:
  title: "Logging/Monitoring Change"
  patterns:
    - "**/logging/*"
    - "**/monitoring/*"
    - "*logger*"
    - "*metrics*"
    - "*datadog*"
    - "*newrelic*"
  questions:
    - "Is PII being logged?"
    - "Will this increase log volume significantly?"
    - "Are appropriate log levels used?"
    - "Are dashboards/alerts updated?"
```

### Mobile / Native

```yaml
mobile:
  title: "Mobile/Native Code"
  patterns:
    - "ios/**"
    - "android/**"
    - "*.swift"
    - "*.kt"
    - "*.m"
  questions:
    - "Is this backwards compatible with older app versions?"
    - "Does this require an app store release?"
    - "Has QA tested on physical devices?"
    - "Are there platform-specific considerations?"
```

### GraphQL Schema

```yaml
graphql:
  title: "GraphQL Schema Change"
  patterns:
    - "*.graphql"
    - "**/graphql/**"
    - "*_type.rb"
    - "*Type.ts"
  questions:
    - "Is this a breaking change to the schema?"
    - "Are deprecated fields marked properly?"
    - "Have client teams been notified?"
    - "Is there a migration path for clients?"
```

---

## Pattern Syntax

- **Simple patterns** (no `/`) match the filename only:
  - `*.test.ts` matches `foo.test.ts` in any directory
  - `Dockerfile*` matches `Dockerfile`, `Dockerfile.dev`, etc.

- **Path patterns** (contain `/`) match the full path:
  - `*/api/*` matches `src/api/users.ts`
  - `terraform/**` matches any file under a `terraform` directory

---

## Best Practices

1. **Be specific with patterns** - Avoid overly broad patterns like `*.yaml` that match too many files

2. **Limit questions to 3-6** - Too many questions slow down development without adding value

3. **Include stop conditions** - Use `**(STOP IF YES)**` for questions that should halt work

4. **Customize for your team** - Add categories relevant to your domain (e.g., HIPAA for healthcare, PCI for payments)

5. **Review periodically** - Remove categories that aren't providing value, add new ones as needs emerge
