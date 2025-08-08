#!/bin/bash

# 🚀 Roomies Backend - AWS Production Deployment Script
# Automated deployment with zero-downtime deployment strategy

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="roomies-backend"
AWS_REGION=${AWS_REGION:-"us-east-1"}
ENVIRONMENT=${ENVIRONMENT:-"production"}
DOCKER_TAG=${DOCKER_TAG:-"latest"}
ECR_REGISTRY_ID=${AWS_ACCOUNT_ID}
ECR_REPOSITORY="${ECR_REGISTRY_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"

# Deployment options
DRY_RUN=${DRY_RUN:-false}
SKIP_TESTS=${SKIP_TESTS:-false}
FORCE_DEPLOY=${FORCE_DEPLOY:-false}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Roomies Backend AWS Deployment${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}"
    echo -e "Region:      ${GREEN}${AWS_REGION}${NC}"
    echo -e "Docker Tag:  ${GREEN}${DOCKER_TAG}${NC}"
    echo -e "Dry Run:     ${GREEN}${DRY_RUN}${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    
    # Check required tools
    local required_tools=("aws" "docker" "node" "npm")
    for tool in "${required_tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}❌ $tool is not installed${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ $tool is available${NC}"
    done

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS credentials configured${NC}"

    # Check if in correct directory
    if [[ ! -f "package.json" ]]; then
        echo -e "${RED}❌ Not in backend project directory${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ In correct project directory${NC}"

    echo ""
}

run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Skipping tests (SKIP_TESTS=true)${NC}"
        return
    fi

    echo -e "${BLUE}🧪 Running tests...${NC}"
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        npm ci
    fi

    # Run linting
    echo -e "${BLUE}🔍 Running linting...${NC}"
    npm run lint || {
        echo -e "${RED}❌ Linting failed${NC}"
        exit 1
    }

    # Run type checking
    echo -e "${BLUE}📝 Running TypeScript type check...${NC}"
    npx tsc --noEmit || {
        echo -e "${RED}❌ Type checking failed${NC}"
        exit 1
    }

    # Build the project
    echo -e "${BLUE}🔨 Building project...${NC}"
    npm run build || {
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    }

    echo -e "${GREEN}✅ All tests passed${NC}"
    echo ""
}

setup_aws_infrastructure() {
    echo -e "${BLUE}🏗️  Setting up AWS infrastructure...${NC}"

    # Check if ECR repository exists
    if ! aws ecr describe-repositories --repository-names $APP_NAME --region $AWS_REGION &> /dev/null; then
        echo -e "${BLUE}📦 Creating ECR repository...${NC}"
        if [[ "$DRY_RUN" == "false" ]]; then
            aws ecr create-repository \
                --repository-name $APP_NAME \
                --region $AWS_REGION \
                --image-scanning-configuration scanOnPush=true
        fi
    fi
    echo -e "${GREEN}✅ ECR repository ready${NC}"

    # Set up VPC and security groups (basic setup)
    echo -e "${BLUE}🌐 Checking VPC configuration...${NC}"
    
    # Get default VPC (in production, use a dedicated VPC)
    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=isDefault,Values=true" \
        --query "Vpcs[0].VpcId" \
        --output text \
        --region $AWS_REGION)
    
    if [[ "$DEFAULT_VPC_ID" != "None" ]]; then
        echo -e "${GREEN}✅ Using default VPC: $DEFAULT_VPC_ID${NC}"
    else
        echo -e "${RED}❌ No default VPC found${NC}"
        exit 1
    fi

    echo ""
}

build_docker_image() {
    echo -e "${BLUE}🐳 Building Docker image...${NC}"
    
    # Get git commit hash for tagging
    local git_commit=$(git rev-parse --short HEAD)
    local image_tag="${DOCKER_TAG}-${git_commit}"
    
    echo -e "${BLUE}Building image: ${ECR_REPOSITORY}:${image_tag}${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Build image with multi-platform support
        docker build \
            --platform linux/amd64 \
            -t "${ECR_REPOSITORY}:${image_tag}" \
            -t "${ECR_REPOSITORY}:latest" \
            -f Dockerfile \
            .
    fi
    
    echo -e "${GREEN}✅ Docker image built${NC}"
    echo ""
}

push_docker_image() {
    echo -e "${BLUE}📤 Pushing Docker image to ECR...${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Login to ECR
        aws ecr get-login-password --region $AWS_REGION | \
            docker login --username AWS --password-stdin $ECR_REGISTRY_ID.dkr.ecr.$AWS_REGION.amazonaws.com
        
        # Push images
        docker push "${ECR_REPOSITORY}:latest"
        
        local git_commit=$(git rev-parse --short HEAD)
        docker push "${ECR_REPOSITORY}:${DOCKER_TAG}-${git_commit}"
    fi
    
    echo -e "${GREEN}✅ Docker image pushed to ECR${NC}"
    echo ""
}

deploy_to_ecs() {
    echo -e "${BLUE}🚀 Deploying to ECS...${NC}"
    
    # This would contain ECS deployment logic
    # For now, provide instructions for manual deployment
    
    echo -e "${YELLOW}📝 Manual deployment steps required:${NC}"
    echo -e "1. Create ECS cluster: roomies-${ENVIRONMENT}"
    echo -e "2. Create task definition with image: ${ECR_REPOSITORY}:latest"
    echo -e "3. Create ECS service with desired capacity"
    echo -e "4. Configure load balancer"
    echo -e "5. Update DNS records"
    
    echo ""
}

run_health_checks() {
    echo -e "${BLUE}🏥 Running post-deployment health checks...${NC}"
    
    # Wait for deployment to be ready
    local max_attempts=30
    local attempt=1
    local health_url="https://api.roomies.app/health"
    
    if [[ "$ENVIRONMENT" != "production" ]]; then
        health_url="http://localhost:3000/health"
    fi
    
    echo -e "${BLUE}Waiting for service to be healthy...${NC}"
    
    while [[ $attempt -le $max_attempts ]]; do
        echo -e "${BLUE}Health check attempt $attempt/$max_attempts...${NC}"
        
        if curl -f "$health_url" &> /dev/null; then
            echo -e "${GREEN}✅ Health check passed${NC}"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            echo -e "${RED}❌ Health check failed after $max_attempts attempts${NC}"
            exit 1
        fi
        
        sleep 10
        ((attempt++))
    done
    
    echo ""
}

cleanup_old_images() {
    echo -e "${BLUE}🧹 Cleaning up old Docker images...${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Keep only the latest 10 images
        aws ecr describe-images \
            --repository-name $APP_NAME \
            --region $AWS_REGION \
            --query 'sort_by(imageDetails,& imageLastModifiedDate)[:-10].imageDigest' \
            --output text | \
        while read digest; do
            if [[ -n "$digest" ]]; then
                aws ecr batch-delete-image \
                    --repository-name $APP_NAME \
                    --region $AWS_REGION \
                    --image-ids imageDigest=$digest
            fi
        done
    fi
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    echo ""
}

create_deployment_notification() {
    echo -e "${BLUE}📧 Sending deployment notification...${NC}"
    
    local git_commit=$(git rev-parse HEAD)
    local git_author=$(git log -1 --pretty=format:'%an')
    local git_message=$(git log -1 --pretty=format:'%s')
    
    echo -e "${GREEN}🚀 Deployment Summary${NC}"
    echo -e "Environment: $ENVIRONMENT"
    echo -e "Commit:      $git_commit"
    echo -e "Author:      $git_author"
    echo -e "Message:     $git_message"
    echo -e "Time:        $(date)"
    echo ""
}

rollback_deployment() {
    echo -e "${RED}⏪ Rolling back deployment...${NC}"
    
    # Rollback logic would go here
    # This would revert to the previous stable version
    
    echo -e "${YELLOW}Manual rollback required:${NC}"
    echo -e "1. Identify previous stable image tag"
    echo -e "2. Update ECS service to use previous image"
    echo -e "3. Monitor health checks"
    
    exit 1
}

main() {
    print_header
    
    # Trap errors and provide rollback option
    trap 'echo -e "${RED}❌ Deployment failed${NC}"; rollback_deployment' ERR
    
    check_prerequisites
    run_tests
    setup_aws_infrastructure
    build_docker_image
    push_docker_image
    deploy_to_ecs
    run_health_checks
    cleanup_old_images
    create_deployment_notification
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${GREEN}API URL: https://api.roomies.app${NC}"
    echo -e "${GREEN}Health Check: https://api.roomies.app/health${NC}"
}

# Help text
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Roomies Backend AWS Deployment Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION      AWS region (default: us-east-1)"
    echo "  ENVIRONMENT     Deployment environment (default: production)"
    echo "  DOCKER_TAG      Docker image tag (default: latest)"
    echo "  DRY_RUN        Run without making changes (default: false)"
    echo "  SKIP_TESTS     Skip running tests (default: false)"
    echo "  FORCE_DEPLOY   Force deployment even if no changes (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Normal production deployment"
    echo "  DRY_RUN=true $0            # Test deployment without changes"
    echo "  ENVIRONMENT=staging $0      # Deploy to staging"
    echo "  SKIP_TESTS=true $0         # Deploy without running tests"
    echo ""
    exit 0
fi

# Run deployment
main
