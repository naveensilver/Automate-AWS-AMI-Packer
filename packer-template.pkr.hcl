# packer-template.pkr.hcl

# Source block: Define the AWS EC2 instance details to create the AMI
source "amazon-ebs" "ubuntu" {
  ami_name      = "my-ubuntu-ami-{{timestamp}}"
  instance_type = "t2.micro"
  region        = "us-east-1"
  source_ami    = "ami-0866a3c8686eaeeba"  # Replace with a real base AMI ID from AWS EC2 - UBUNTU IMAGE ID
  ssh_username  = "ubuntu"

  ami_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 8  # Correct field for volume size
  }
}

# Build block: Defines the provisioning steps
build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",   # Disable interactive prompts
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx"
    ]
  }
}

