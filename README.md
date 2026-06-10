# 🔄 Automated Self-Healing System

A DevOps/SRE proof-of-concept that monitors a Java service for crashes, automatically restarts it, archives crash evidence to S3, and fires an SNS alert — all provisioned locally with **LocalStack** and **Terraform**.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        monitor.sh (Bash)                        │
│                                                                 │
│  1. Compile & launch UnstableApp.java                           │
│  2. Poll every 5 s — is app.pid present?                        │
│         │                                                       │
│    YES ──┤  [HEALTHY] → log heartbeat, keep polling             │
│         │                                                       │
│    NO  ──┤  [CRASH DETECTED]                                    │
│         │   ├─ Upload application.log  ──►  S3 (LocalStack)    │
│         │   ├─ Publish SNS alert       ──►  SNS (LocalStack)   │
│         │   └─ Restart UnstableApp     ──►  Self-Healing ✓     │
└─────────────────────────────────────────────────────────────────┘

UnstableApp.java
  ├─ Writes app.pid on start   (health probe anchor)
  ├─ Processes 15 mock requests (1 s each)
  ├─ Crashes with OOM error
  └─ Deletes app.pid on exit   (crash signal to monitor)

main.tf (Terraform + LocalStack)
  ├─ aws_s3_bucket  → zoho-crash-logs-archive
  └─ aws_sns_topic  → zoho-critical-alerts
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Java (plain JDK, no framework) |
| Monitor / Orchestrator | Bash |
| Cloud Emulation | [LocalStack](https://localstack.cloud/) |
| Infrastructure as Code | Terraform (AWS provider ~5.0) |
| AWS Services Used | S3, SNS |

---

## Prerequisites

| Tool | Tested Version | Notes |
|---|---|---|
| JDK | 11+ | `javac` and `java` must be on PATH |
| LocalStack | 2.x+ | Run via Docker or `pip install localstack` |
| AWS CLI | 2.x | Configure a local profile (e.g. `localstack`) |
| Terraform | 1.x | `terraform` on PATH |

---

## Quick Start

### 1 — Start LocalStack

```bash
localstack start          # or: docker run -p 4566:4566 localstack/localstack
```

### 2 — Provision AWS Resources

```bash
terraform init
terraform apply -auto-approve
```

This creates the S3 bucket (`zoho-crash-logs-archive`) and SNS topic (`zoho-critical-alerts`) inside LocalStack.

### 3 — Configure Environment

Create a `.env` file in the project root:

```dotenv
APP_NAME=UnstableApp

# LocalStack endpoint
AWS_ENDPOINT=http://localhost:4566
AWS_PROFILE=localstack          # must exist in ~/.aws/credentials

# Provisioned by Terraform (step 2)
S3_BUCKET=s3://zoho-crash-logs-archive
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:000000000000:zoho-critical-alerts
```

> **Tip:** Get the exact SNS ARN after provisioning with:
> ```bash
> aws --endpoint-url=http://localhost:4566 --profile localstack \
>     sns list-topics --query 'Topics[*].TopicArn' --output text
> ```

### 4 — Run the Monitor

```bash
chmod +x monitor.sh
./monitor.sh
```

The script compiles the Java source, launches the app, and enters its watch loop. You'll see output like:

```
[CI/CD] Compiling UnstableApp...
Build Success! Starting Monitor...
[10:42:01] System Healthy
[10:42:06] System Healthy
...
[10:42:31] CRITICAL ALERT: UnstableApp has crashed!
   Uploading evidence to S3...
   Sending SNS Alert...
   Initiating Self-Healing...
Starting UnstableApp...
[10:42:38] System Healthy
```

---

## Project Structure

```
.
├── UnstableApp.java   # Intentionally unstable Java service (simulates OOM crash)
├── monitor.sh         # Crash-detection, evidence upload, auto-restart loop
├── main.tf            # Terraform: S3 bucket + SNS topic on LocalStack
├── .env               # Runtime config (not committed — see .gitignore)
└── .gitignore
```

---

## Architecture Decisions

**PID file as health probe** — A simple, language-agnostic mechanism: the app creates `app.pid` on startup and deletes it on exit. The monitor treats its absence as a crash signal without needing an HTTP health endpoint.

**LocalStack for AWS emulation** — The entire cloud layer (S3 + SNS) runs locally on `localhost:4566`, making the system fully self-contained with no AWS account or credentials required for development.

**Terraform for IaC** — Infrastructure is code-defined and reproducible. A single `terraform apply` rebuilds the entire environment from scratch.

**Bash monitor loop** — Intentionally lightweight. No external dependencies, no daemon framework; the polling loop is transparent and easy to extend (e.g. add PagerDuty, Slack, or email hooks).

---

## Concepts Demonstrated

- **Self-healing infrastructure** — automated failure detection and service restart
- **Observability** — structured timestamped logging, crash evidence archival to S3
- **Alerting pipeline** — SNS publish on crash for downstream notification integrations
- **Infrastructure as Code** — reproducible AWS resource provisioning with Terraform
- **CI/CD pattern** — compile → deploy → monitor in a single script
- **LocalStack integration** — cloud-native development without a live AWS environment

---

## Extending This Project

- **Add an SNS email subscription** — get a real email when the app crashes
- **Parameterize crash threshold** — count restarts and alert differently after N failures
- **Swap SNS for Slack webhook** — post crash alerts directly to a channel
- **Dockerize** — containerize the Java app and mount the monitor as an entrypoint
- **Replace PID file with HTTP health check** — `curl -f http://localhost:8080/health || crash_handler`
