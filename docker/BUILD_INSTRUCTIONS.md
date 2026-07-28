# Docker Image Build Instructions

Since Docker daemon isn't available on SageMaker notebook instances, here are practical ways to build and use these images.

## Option 1: Build Locally on Your Laptop (Recommended)

### Prerequisites
- Docker Desktop installed (Mac/Windows) or Docker Engine (Linux)
- AWS CLI configured with your credentials

### Steps

1. **Clone this repository to your laptop:**
```bash
git clone <your-repo-url>
cd nextflow/docker
```

2. **Login to AWS ECR:**
```bash
# Replace with your AWS account ID and region
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  335777049998.dkr.ecr.us-east-1.amazonaws.com
```

3. **Create ECR repositories (one-time setup):**
```bash
aws ecr create-repository --repository-name finemapping-gwaslab --region us-east-1
aws ecr create-repository --repository-name finemapping-plink --region us-east-1
aws ecr create-repository --repository-name finemapping-susie --region us-east-1
```

4. **Build and push images:**
```bash
./build_all.sh 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping
./push_all.sh 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping
```

5. **Run pipeline on SageMaker with ECR images:**
```bash
# Back on SageMaker
nextflow run finemapping_susie_docker.nf \
  -c nextflow.docker.config \
  --registry 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping \
  --sumstats /path/to/data.tsv \
  --genotype_prefix /path/to/genotypes
```

## Option 2: AWS CodeBuild (Fully Automated)

### Setup (one-time)

1. **Push Dockerfiles to GitHub/CodeCommit**
2. **Create CodeBuild project via AWS Console:**
   - Source: Your repository
   - Environment: `aws/codebuild/standard:7.0`
   - Buildspec: See `buildspec.yml` below

3. **Create `buildspec.yml` in docker/ directory:**

```yaml
version: 0.2

env:
  variables:
    AWS_DEFAULT_REGION: us-east-1
    AWS_ACCOUNT_ID: 335777049998
    IMAGE_REPO_NAME_PREFIX: finemapping

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building gwaslab image...
      - docker build -t $IMAGE_REPO_NAME_PREFIX-gwaslab:$IMAGE_TAG -t $IMAGE_REPO_NAME_PREFIX-gwaslab:latest gwaslab/
      - echo Building plink image...
      - docker build -t $IMAGE_REPO_NAME_PREFIX-plink:$IMAGE_TAG -t $IMAGE_REPO_NAME_PREFIX-plink:latest plink/
      - echo Building susie image...
      - docker build -t $IMAGE_REPO_NAME_PREFIX-susie:$IMAGE_TAG -t $IMAGE_REPO_NAME_PREFIX-susie:latest susie/
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing images to ECR...
      - docker tag $IMAGE_REPO_NAME_PREFIX-gwaslab:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-gwaslab:$IMAGE_TAG
      - docker tag $IMAGE_REPO_NAME_PREFIX-gwaslab:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-gwaslab:latest
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-gwaslab:$IMAGE_TAG
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-gwaslab:latest
      
      - docker tag $IMAGE_REPO_NAME_PREFIX-plink:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-plink:$IMAGE_TAG
      - docker tag $IMAGE_REPO_NAME_PREFIX-plink:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-plink:latest
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-plink:$IMAGE_TAG
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-plink:latest
      
      - docker tag $IMAGE_REPO_NAME_PREFIX-susie:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-susie:$IMAGE_TAG
      - docker tag $IMAGE_REPO_NAME_PREFIX-susie:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-susie:latest
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-susie:$IMAGE_TAG
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME_PREFIX-susie:latest
```

### Trigger build:
```bash
aws codebuild start-build --project-name finemapping-docker-build
```

## Option 3: AWS Cloud9 (Browser-Based)

1. **Create Cloud9 environment:**
   - AWS Console → Cloud9 → Create environment
   - Choose t3.medium or larger
   - Amazon Linux 2

2. **Clone repo and build:**
```bash
git clone <your-repo>
cd nextflow/docker

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  335777049998.dkr.ecr.us-east-1.amazonaws.com

# Build and push
./build_all.sh 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping
./push_all.sh 335777049998.dkr.ecr.us-east-1.amazonaws.com/finemapping
```

3. **Delete Cloud9 environment when done** (to save costs)

## Option 4: Temporary EC2 Instance

```bash
# Launch EC2 instance with Docker
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --key-name your-key \
  --user-data '#!/bin/bash
yum update -y
yum install -y docker git
systemctl start docker
usermod -a -G docker ec2-user'

# SSH into instance and build images
# Then terminate instance when done
```

## Option 5: Use Public Pre-built Images (Alternative)

If you don't want to build custom images, you can use public images and install packages at runtime:

```nextflow
process LOAD_SUMSTATS {
    container "mambaorg/micromamba:1.5.8"
    
    script:
    """
    micromamba install -y -n base -c conda-forge python=3.12 pandas numpy
    pip install gwaslab
    python << 'EOF'
    # Your code here
    EOF
    """
}
```

**Trade-off:** Slower (installs packages every time) but no image building needed.

## Recommended Workflow for Your Use Case

For a research pipeline like this, I recommend:

1. **Development phase:** Use conda version (`finemapping_susie.nf`) on SageMaker
2. **Production phase:** Build Docker images locally or via CodeBuild
3. **Share with collaborators:** Push images to ECR, share the docker pipeline

This way you can iterate quickly during development, then lock down the environment with Docker when ready to share or run at scale.
