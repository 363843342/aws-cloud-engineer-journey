# Week 3 Runbook: AWS EC2 & EBS

## Lab 3.1: Deploy PropertyLite to EC2

1. **Launch EC2 Instance**: Create an `Amazon Linux 2023` (`t3.micro`) instance named `property-api-01` in the AWS Console[cite: 1].
2. **Create Key Pair**: Generate and download an RSA key pair named `training-key.pem` to your local machine[cite: 1].
3. **Configure Security Group**: Create a security group with inbound rules allowing SSH (Port 22, restricted to My IP) and Custom TCP (Port 8080, Anywhere)[cite: 1, 2].
4. **Fill User Data**: Paste the Bash bootstrapping script into the User data field under Advanced details to automatically deploy the Flask app and CSV data[cite: 1, 4].
5. **Set Key Permissions**: Execute `chmod 400 ~/.ssh/training-key.pem` in your local terminal to restrict key file permissions[cite: 1, 2].
6. **Connect via SSH**: Log into the EC2 instance using `ssh -i ~/.ssh/training-key.pem ec2-user@<EC2_PUBLIC_IP>`[cite: 1].
7. **Verify API Service**: Test the endpoint with `curl http://<EC2_PUBLIC_IP>:8080/health` and the property query endpoint to confirm the service is running successfully in the background[cite: 2, 4].

---

## Lab 3.2: EBS Snapshot Practice

1. **Locate Root Volume**: Select the root storage volume attached to the `property-api-01` instance on the EC2 Volumes page[cite: 2].
2. **Create Volume Snapshot**: Click Actions, select Create snapshot, and wait until the snapshot status changes to completed[cite: 2].
**Snapshot Question**: If a new EBS volume is created from this snapshot, it will contain a exact copy of all data, files, and system state from the original volume at the exact moment the snapshot was taken[cite: 2].

---

## Lab 3.3: Debug SSH Connection Timeout

1. **Diagnose Timeout Cause**: Check your current local public IP using `curl ifconfig.me` to verify if a dynamic IP change invalidated the original My IP rule in the security group[cite: 2, 3].
2. **Update Inbound Rule**: Edit the SSH Port 22 inbound rule in the security group with your updated public IP to restore access[cite: 3].

---

## Cleanup

1. **Terminate Instance**: Click Terminate on the EC2 instance in the console and confirm that the attached EBS volume is deleted as well[cite: 3].

Powered by Gemini Exporter (https://www.ai-chat-exporter.com)
