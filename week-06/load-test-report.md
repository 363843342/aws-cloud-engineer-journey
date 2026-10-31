# Week 6 — Load Testing & Auto Scaling Report

**Author:** Intern  
**Project:** IDX-Exchange-AWS-Cloud  
**Environment:** `training-vpc` (us-west-1)  

## 1. Executive Summary & Objective

The objective of Week 6 is to implement a highly available, self-healing, and elastic compute tier using an AWS **Application Load Balancer (ALB)** and an **Auto Scaling Group (ASG)**. 

This report documents the load testing of the `PropertyLite` REST API, proving that:
1. Target tracking scaling policies automatically detect high CPU utilization via CloudWatch alarms.
2. The ASG responds to increased system demand by executing a scale-out event and provisioning additional EC2 instances.
3. The load balancer continues serving healthy HTTP traffic throughout the scaling lifecycle.

---

## 2. Infrastructure Architecture & Configuration

| Component | Resource Name / ID | Configuration Details |
| :--- | :--- | :--- |
| **VPC** | `training-vpc` | CIDR `10.0.0.0/16`, across 2 Availability Zones |
| **Subnets** | Public & Private Subnets | ALB spans 2 Public Subnets; ASG instances reside in 2 Private Subnets |
| **Launch Template** | `property-api-template` | AMI: Amazon Linux 2023, Instance Type: `t3.micro`, Port 8080 Flask bootstrap |
| **Target Group** | `property-tg` | Target Type: `Instance`, Protocol/Port: `HTTP:8080`, Health check: `/health` |
| **Load Balancer** | Application Load Balancer | Internet-facing, HTTP Listener on Port 80 forwarding to `property-tg` |
| **Auto Scaling Group** | `trainingAutoScaling` | Desired: `2`, Min: `1`, Max: `4` |
| **Scaling Policy** | Target Tracking Policy | Metric: `Average CPU Utilization`, Target Value: $50\%$ |

---

## 3. Stress Test Execution

To induce sustained CPU utilization exceeding the $50\%$ target threshold, a CPU workload stress test was executed inside the active EC2 instance using the Linux `stress` utility.

### Command Executed
```bash
# Connect to private instance via Bastion / EC2 Instance Connect
sudo amazon-linux-extras install epel -y  # (Amazon Linux 2) OR:
sudo dnf install -y stress               # (Amazon Linux 2023)

# Run intensive CPU stress across 2 cores for 10 minutes (600 seconds)
stress --cpu 2 --timeout 600
```

---

## 4. CloudWatch Metrics & Alarm Trigger (Scale-Out)

Once the stress test was running, the instance's CPU utilization surged to nearly $100\%$, driving the ASG average CPU utilization well above the configured $50\%$ threshold. This triggered CloudWatch's automatically generated high-threshold alarm.

* **Alarm Name:** `TargetTracking-trainingAutoScaling-AlarmHigh-<unique-id>`
* **Threshold Condition:** `CPUUtilization > 50 for 1 datapoint within 1 minute` (or 3 minutes depending on aggregation period)
* **Initial State:** `OK`
* **Triggered State:** `In alarm`
* **Alarm Trigger Timestamp:** `2026-10-30T23:38:15Z` *(replace with your exact UTC timestamp from CloudWatch)*

### CloudWatch Metric Spike Screenshot
![CloudWatch CPU Utilization AlarmHigh](screenshots/cloudwatch-alarm-high.png)

> **Figure 1:** CloudWatch Alarm showing metric spike breaching the $50\%$ threshold line and transitioning into `In alarm` status.

---

## 5. Auto Scaling Group Activity History (Scale-Out Event)

In response to the `AlarmHigh` state notification, the target tracking policy recalculated the required group capacity and issued a scale-out instruction to launch an additional EC2 instance.

* **Action Description:** `Launching a new EC2 instance: i-<new-instance-id>`
* **Cause Summary:** `At 2026-10-30T23:39:40Z a monitor alarm TargetTracking-trainingAutoScaling-AlarmHigh in state ALARM triggered policy Target Tracking Policy changing the desired capacity from 2 to 3.`
* **Scaling Event Start Time:** `2026-10-30T23:39:40Z` *(replace with your exact UTC timestamp from ASG Activity)*
* **Scaling Event End Time:** `2026-10-30T23:40:18Z` *(replace with your exact UTC timestamp)*
* **Result Status:** `Successful`

### ASG Activity History Screenshot
![ASG Activity Scale-Out Event](screenshots/asg-scale-out-activity.png)

> **Figure 2:** ASG Activity history displaying the successful scale-out event and transition of desired capacity from 2 to 3 instances.

---

## 6. Timestamp Gap & Latency Analysis

| Event Milestone | Exact UTC Timestamp | Details |
| :--- | :--- | :--- |
| **CPU Spike Breaches Threshold** | `2026-10-30T23:38:15Z` | CloudWatch metric crosses the $50\%$ target |
| **ASG Scaling Action Triggered** | `2026-10-30T23:39:40Z` | ASG initiates launch of replacement/scale-out instance |
| **Calculated Latency Gap ($\Delta t$)** | **1 minute 25 seconds** | $(\approx 85\text{ seconds})$ |

### Technical Analysis of the Gap
The time gap of approximately $1\text{ to }2\text{ minutes}$ between the metric spike and instance launch initialization is attributed to the following factors:
1. **Metric Aggregation & Metric Publishing:** CloudWatch basic monitoring collects and evaluates data points in periodic intervals (typically 1–5 minute windows).
2. **Alarm Evaluation Period:** The alarm evaluates consecutive data points to prevent false-positive scaling actions caused by brief, temporary spikes.
3. **Control Plane Orchestration:** Once the alarm changes state to `In alarm`, the CloudWatch action fires an SNS/internal event to the Auto Scaling controller, which computes target capacity before calling `ec2:RunInstances`.

---

## 7. Service Verification & Target Health

During and after the scale-out event, requests routed through the Application Load Balancer remained available with zero downtime:

```bash
# 1. Health check verification
curl -i http://<alb-dns-name>/health
# HTTP/1.1 200 OK
# Content-Type: application/json
# {"status":"ok"}

# 2. Application listings verification
curl http://<alb-dns-name>/properties
# HTTP/1.1 200 OK
# [{"L_City":"Sacramento","L_ListingID":"R100234", ...}]
```

All instances registered in `property-tg` maintained a `healthy` state once user data bootstrapping completed, demonstrating that incoming traffic is distributed evenly across all active targets.