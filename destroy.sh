
#!/bin/bash
cd ../terraform
terraform init
terraform apply -auto-approve -var="win10_count=2" -var="win11_count=2" -var="linux_count=2"
