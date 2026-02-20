# Your lifecycle hook name, must match the one defined in Terraform
LIFECYCLE_HOOK_NAME="LifecycleHookWhenLaunching"

# 1. Get token for IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# 2. Get instance ID
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    -s http://169.254.169.254/latest/meta-data/instance-id)

# 3. Get ASG name
ASG_NAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    -s http://169.254.169.254/latest/meta-data/tags/instance/aws:autoscaling:groupName)

# 4. Get Region
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=${AZ%?}

# Send signal to ASG that lifecycle action is complete
aws autoscaling complete-lifecycle-action \
    --lifecycle-hook-name $LIFECYCLE_HOOK_NAME \
    --auto-scaling-group-name $ASG_NAME \
    --instance-id $INSTANCE_ID \
    --lifecycle-action-result CONTINUE \
    --region $REGION

# Log for debugging purposes
echo "Lifecycle action completed for instance: $INSTANCE_ID" >> /var/log/lifecycle-hook.log
echo "ASG Name: $ASG_NAME" >> /var/log/lifecycle-hook.log
echo "Region: $REGION" >> /var/log/lifecycle-hook.log