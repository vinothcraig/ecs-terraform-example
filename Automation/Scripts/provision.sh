#!/bin/bash
deploy() {
        echo 
        echo ---------------------------
        echo
        echo ">> Stage 1 :: Creating ECR repository.."
        echo
        echo
        cd ../Terraform/Repository
        terraform init
        terraform apply -auto-approve
        if [ $? -ne 0 ]; then
            echo 
            echo 
            echo " Execution Failed.."
            echo
            echo
        fi
        echo 
        echo ---------------------------
        echo 
        echo ">> Stage 2 :: Creating Docker image.."
        echo 
        echo
        cd ../../..
        docker build -t 662343139402.dkr.ecr.us-east-1.amazonaws.com/api-ecr-repo:latest .
        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 662343139402.dkr.ecr.us-east-1.amazonaws.com
        docker push 662343139402.dkr.ecr.us-east-1.amazonaws.com/api-ecr-repo:latest
        if [ $? -ne 0 ]; then
            echo 
            echo 
            echo "Execution Failed.."
            echo
            echo
        fi
        echo
        echo ---------------------------
        echo 
        echo ">> Stage 3 :: Creating AWS Network & ECS.."
        echo 
        echo 
        cd Automation/Terraform/OtherResources
        terraform init
        terraform apply -auto-approve
        if [ $? -ne 0 ]; then
            echo 
            echo 
            echo "Execution Failed.."
            echo
            echo
        else
            echo
            echo
            echo "Completed.. Use "https://api.test.rightrev.cloud" to access your application.."
            echo
        fi
        echo
        echo ---------------------------
        echo
}

destroy() {
        echo
        echo ---------------------------
        echo
        echo ">> Stage 1 :: Destroying ECR repository.."
        echo      
        echo
        cd ../Terraform/Repository
        terraform destroy -auto-approve
        if [ $? -ne 0 ]; then
            echo 
            echo 
            echo "Execution Failed.."
            echo
            echo
        fi
        echo 
        echo ---------------------------
        echo 
        echo ">> Stage 2 :: Destroying AWS Network & ECS.."
        echo 
        echo 
        cd ../OtherResources
        terraform destroy -auto-approve
        if [ $? -ne 0 ]; then
            echo 
            echo 
            echo "Execution Failed.."
            echo
            echo
        fi
        echo
        echo ---------------------------
        echo

}

input=$1
if [ "$input" = "deploy" ]; then 
    deploy
elif [ "$input" = "destroy" ]; then
    destroy
else 
    echo "Valid inputs -> [deploy/destroy]"
fi
