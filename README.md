# Automating AWS AMI creation with HashiCorp Packer

### What is an **AWS AMI**?

An **Amazon Machine Image (AMI)** is essentially a template used to create a **virtual machine (VM)** on **Amazon Web Services (AWS)**. It contains all the software (including the operating system, application server, applications, and settings) required to launch an instance on AWS.

Think of an AMI as a snapshot or image of a machine that you can use to launch one or more EC2 instances in AWS. 

For example, if you want to quickly launch multiple web servers that all run the same version of Ubuntu and have Nginx installed, you can create an AMI that includes the operating system, Nginx, and any other custom configurations. Then, you can launch multiple EC2 instances from this AMI, which all have the same setup.

---

### What is **HashiCorp Packer**?

**HashiCorp Packer** is a tool used to **automate the creation of machine images**. It's a powerful tool that allows you to define your machine image's configuration and automate its creation. Packer works across multiple platforms (AWS, Google Cloud, VMware, VirtualBox, etc.).

Packer automates the process of creating **consistent, repeatable machine images**. This can be used for both virtual machines (VMs) and cloud instances. Packer helps eliminate the need to manually set up your environment each time you need a new machine image by automating the provisioning and building of the image.

---

### How Does Packer and AWS AMI Work Together?

Here’s how **Packer** works with **AWS AMI**:

1. **Base Image**: You start with a **base AMI** (e.g., a fresh Ubuntu image from AWS).
2. **Provisioning**: You define how to customize that base image. This can include installing software, configuring security settings, or making any other changes you need.
3. **Building the AMI**: Packer takes care of launching a temporary instance in AWS, applying the changes (provisioning), and then creating a new AMI from that instance.
4. **Resulting AMI**: Once the process is complete, you have a new AMI that can be used to launch consistent, identical EC2 instances.

This allows you to automate your infrastructure and create standardized, reusable AMIs for your applications.

---

### Simple Example: 

Let’s say you need a new EC2 instance that runs Ubuntu, Nginx, and some custom software. Normally, you'd have to:

- Launch an EC2 instance from an Ubuntu AMI.
- SSH into the instance, install Nginx and your software, and configure the system.
- After everything is set up, you can create an AMI of that instance to use as a template for other instances.

With **Packer**, you can automate this process:

1. You create a **Packer template** (a configuration file).
2. Packer will:
   - Launch an EC2 instance.
   - Install Nginx and your software (via provisioning steps).
   - Create an AMI of the customized instance.
3. You can then use this newly created AMI to launch identical instances whenever needed.

### Why Use Packer?

- **Consistency**: With Packer, you can ensure that every instance launched from an AMI is exactly the same. No manual setup or configuration errors.
- **Automation**: Packer automates the entire process, saving time and reducing human error.
- **Speed**: Instead of manually creating and configuring new instances, you can quickly deploy new environments by launching instances from pre-configured AMIs.
- **Reproducibility**: The same Packer configuration file can be reused to create identical AMIs in the future.

---

### In Summary:

- **AWS AMI**: A snapshot or template that you can use to launch instances on AWS.
- **HashiCorp Packer**: A tool that automates the creation of machine images (like AMIs) with your desired configuration, saving time and ensuring consistency.

# Automating AWS AMI (Hands-ON Implementation)

Let’s go through a hands-on step-by-step implementation of how to automate the creation of AWS AMIs using HashiCorp Packer in a production environment. This will involve:

1. **Setting up AWS Credentials**  
2. **Installing Packer**  
3. **Creating a Packer Template**  
4. **Running the Packer Build**  
5. **Integrating Packer into CI/CD (GitHub Actions example)**  
6. **Post-Processing and Managing AMIs**

We’ll assume you have basic familiarity with AWS and CI/CD workflows, but I’ll provide detailed steps for each part of the process.

### Workflow Diagram

Here's a simplified architecture diagram for this automated process:
```
+------------------------+          +-----------------------------+          +-------------------------+
|                        |          |                             |          |                          |
| GitHub (or CI/CD)      |          |    AWS (EC2, S3, IAM)       |          |   HashiCorp Packer       |
| (Push to Repo)         +--------->+ 1. Launch EC2 instance      +--------->+ 1. Define Packer config  |
|                        |          | 2. Provisioning software    |          |    (AMI, install, config)|
+------------------------+          | 3. Create Custom AMI        |          | 2. Build AMI             |
                                    | 4. Tag AMI                  |          | 3. Execute provisioning  |
                                     | 5. Clean up EC2 instance   |          +-------------------------+
                                     |                            |
                                     +----------------------------+
                                                |
                                                v
                                     +-------------------------+
                                     |                         |
                                     |   AWS AMI Repository    |
                                     | (New AMI Available)     |
                                     +-------------------------+

```
---

### **1. Set Up AWS Credentials**
Before Packer can communicate with AWS, you need to configure AWS credentials.

#### Step 1: AWS Access Keys
To access your AWS resources, you will need an IAM user with the proper permissions. If you don’t have one, follow these steps:

- Go to the [AWS IAM Console](https://console.aws.amazon.com/iam/).
- Create a new user with **Programmatic access**.
- Attach the necessary policies (`AmazonEC2FullAccess`, `AmazonS3FullAccess`, `AmazonVPCFullAccess` for creating AMIs).
- After the user is created, download the **Access Key ID** and **Secret Access Key**.

#### Step 2: Set Environment Variables (Locally)
If running Packer locally, set your AWS credentials as environment variables.

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_REGION="us-east-1"  # or your region
```

Alternatively, you can use AWS CLI to configure them globally (recommended):

```bash
aws configure
```

This command will prompt you for your AWS Access Key, Secret Key, region, and output format.

---

### **2. Install Packer**

#### Step 1: Install Packer Locally
To install Packer on your local system:

**macOS**:

```bash
brew install packer
```

**Linux**:

```bash
# Download the latest Packer release
curl -LO https://releases.hashicorp.com/packer/1.8.3/packer_1.8.3_linux_amd64.zip
unzip packer_1.8.3_linux_amd64.zip
sudo mv packer /usr/local/bin/
```

**Windows**:

- Install via [Chocolatey](https://chocolatey.org/):  
  `choco install packer`

- Or download the `.zip` from [Packer downloads](https://www.packer.io/downloads) and extract it.

Verify the installation by running:

```bash
packer --version
```

---

### **3. Create a Packer Template**

A Packer template defines how to create an AMI. Below is a simple HCL-based Packer template (`packer-template.hcl`) that creates an AWS AMI with basic software installation (e.g., Nginx).

#### Step 1: Define the Template

Create a new file called `packer-template.hcl`:

```hcl
# packer-template.pkr.hcl

# Source block: Define the AWS EC2 instance details to create the AMI
source "amazon-ebs" "ubuntu" {
  ami_name      = "my-ubuntu-ami-{{timestamp}}"
  instance_type = "t2.micro"
  region        = "us-east-1"
  source_ami    = "ami-xxxxxxxx"  # Replace with a real base Ubuntu AMI ID From AWS EC2 Console
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
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx"
    ]
  }
}

```

- **`source "amazon-ebs"`**: This block defines the source EC2 instance (AMI) to use for creating the new AMI. Replace `ami-xxxxxxxx` with the ID of your base AMI (e.g., an Ubuntu AMI or Amazon Linux).
  
- **Provisioner**: The `shell` provisioner runs commands to install software. In this case, we update the package list and install Nginx.

- **`{{timestamp}}`**: The `timestamp` function dynamically generates a unique name for the AMI every time you run the build, preventing name conflicts.

#### Step 2: Validate the Template

Before running the build, ensure your template is valid:

```bash
packer validate packer-template.hcl
```

This should output `Template validated successfully`.

---

### **4. Run Packer Build**

Now you can trigger the build process. This will launch an EC2 instance in your specified region, apply the provisions (install Nginx), and then create the AMI.

```bash
packer build packer-template.hcl
```

Packer will:
1. Launch an EC2 instance from the base AMI.
2. Install the software (Nginx in this case).
3. Create a new AMI from the instance.
4. Terminate the EC2 instance once the AMI is created.

The output will look something like this:

```bash
==> amazon-ebs.ubuntu: AMI: ami-xxxxxxxxxxxxxxxxx
==> amazon-ebs.ubuntu: Waiting for AMI to become ready...
==> amazon-ebs.ubuntu: AMI is ready!
==> amazon-ebs.ubuntu: Cleaning up temporary security group...
==> amazon-ebs.ubuntu: AMI successfully created: ami-xxxxxxxxxxxxxxxxx
```

You can now find the newly created AMI in your AWS Console under **EC2 > AMIs**.

---

### **5. Integrate Packer into CI/CD (GitHub Actions Example)**

Let’s automate the Packer build using GitHub Actions. This way, your AMI is automatically created whenever there’s a change (e.g., a commit to the `main` branch).

#### Step 1: Set Up GitHub Repository

- Create a new GitHub repository or use an existing one.
- Add your `packer-template.hcl` file to the repository.

#### Step 2: Configure GitHub Actions Workflow

Create a new file under `.github/workflows/packer.yml`:

```yaml
name: Build AWS AMI with Packer

on:
  push:
    branches:
      - main  # Trigger on push to the main branch

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: 'us-east-1'

    - name: Install Packer
      run: |
        curl -LO https://releases.hashicorp.com/packer/1.8.3/packer_1.8.3_linux_amd64.zip
        unzip packer_1.8.3_linux_amd64.zip
        sudo mv packer /usr/local/bin/

    - name: Run Packer build
      run: |
        packer build packer-template.hcl
```

- **`aws-actions/configure-aws-credentials`**: This action configures AWS credentials. You'll need to store your AWS Access Key and Secret Key as secrets in the GitHub repository.
  
- **`packer build`**: This step installs Packer and runs the build.

#### Step 3: Add AWS Credentials to GitHub Secrets

Go to your GitHub repository settings:

- **Settings > Secrets > New repository secret**.
- Add two secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

This ensures that the GitHub Action can authenticate to AWS.

#### Step 4: Trigger the Workflow

Push your changes to GitHub, and the GitHub Actions workflow will trigger automatically. It will:

1. Set up AWS credentials.
2. Install Packer.
3. Run the Packer build to create a new AMI.

---

### **6. Post-Processing and Managing AMIs**

You might want to manage the AMIs created by Packer:
- **Tagging the AMI**: You can tag your AMIs to make them easier to identify (e.g., `Environment: Production`, `Version: 1.0`).
- **Deregister Old AMIs**: You may want to periodically deregister old AMIs to avoid unnecessary storage costs.

#### Example: Adding Tags to AMIs in Packer

You can add tags in the `post-processor` block of your template:

```hcl
post-processor "amazon-ami-tag" {
  tags = {
    Name        = "My Custom AMI"
    Environment = "Production"
    Version     = "1.0.0"
  }
}
```

This will apply the specified tags to your newly created AMI.

---

### **Conclusion**

By following these steps, you have automated the process of creating an AWS AMI using HashiCorp Packer. The steps covered:
- AWS credentials setup
- Packer installation
- Writing a Packer template for AMI creation
- Integrating Packer into a CI/CD pipeline (GitHub Actions)
- Tagging and managing AMIs

With this setup, every time you push code to your repository, GitHub Actions will automatically create a new AMI. This ensures your infrastructure is always up to date and ready for deployment.

## Output:

![Screenshot 2024-11-06 001935](https://github.com/user-attachments/assets/9a20f360-4141-4911-867c-1184fe322c36)

![Screenshot 2024-11-06 001838](https://github.com/user-attachments/assets/1eee5c91-d30b-4c7c-a45c-2b691b122ba5)

![Screenshot 2024-11-06 004047](https://github.com/user-attachments/assets/10a0698f-c61f-46fa-945c-22bb60e4afa1)


