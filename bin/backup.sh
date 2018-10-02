#!/bin/bash

# terminate script as soon as any command fails
set -e

if [[ -z "$APP" ]]; then
  echo "Missing APP variable which must be set to the name of your app where the db is located"
  exit 1
fi

if [[ -z "$DATABASE" ]]; then
  echo "Missing DATABASE variable which must be set to the name of the DATABASE you would like to backup"
  exit 1
fi

if [[ -z "$VCO_BACKUPS_ACCESS_KEY_ID" ]]; then
  echo "Missing VCO_BACKUPS_ACCESS_KEY_ID variable which must be set to the AWS access key"
  exit 1
fi

if [[ -z "$VCO_BACKUPS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing VCO_BACKUPS_SECRET_ACCESS_KEY variable which must be set to the AWS secret access key"
  exit 1
fi

if [[ -z "$VCO_BACKUPS_REGION" ]]; then
  echo "Missing VCO_BACKUPS_REGION variable which must be set to the AWS region"
  exit 1
fi




#Get environment variables
#VCO_BACKUPS_ACCESS_KEY_ID=$(cat $ENV_DIR/VCO_BACKUPS_ACCESS_KEY_ID)
#VCO_BACKUPS_SECRET_ACCESS_KEY=$(cat $ENV_DIR/VCO_BACKUPS_SECRET_ACCESS_KEY)
#VCO_BACKUPS_REGION=$(cat $ENV_DIR/VCO_BACKUPS_REGION)
#VCO_BACKUPS_VAULT_NAME=$(cat $ENV_DIR/VCO_BACKUPS_VAULT_NAME)
#VCO_BACKUPS_APP_NAME=$(cat $ENV_DIR/VCO_BACKUPS_APP_NAME)

#install aws-cli
curl https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -o awscli-bundle.zip
unzip awscli-bundle.zip
chmod +x ./awscli-bundle/install
./awscli-bundle/install -i /tmp/aws

#set backup name
BACKUP_FILE_NAME="$(date +"%Y-%m-%d-%H-%M")-$APP-$DATABASE.dump"

#configure aws cli
/tmp/aws/bin/aws configure set aws_access_key_id $VCO_BACKUPS_ACCESS_KEY_ID
/tmp/aws/bin/aws configure set aws_secret_access_key $VCO_BACKUPS_SECRET_ACCESS_KEY
/tmp/aws/bin/aws configure set region $VCO_BACKUPS_REGION


echo "-----> Generating backup ... "
heroku pg:backups capture $DATABASE --app $APP
curl -o $BACKUP_FILE_NAME `heroku pg:backups:url --app $APP`

FINAL_FILE_NAME=$BACKUP_FILE_NAME

if [[ -z "$NOGZIP" ]]; then
  gzip $BACKUP_FILE_NAME
  FINAL_FILE_NAME=$BACKUP_FILE_NAME.gz
fi


echo "-----> backing up to glacier ... "

#/tmp/aws/bin/aws s3 cp $FINAL_FILE_NAME s3://$S3_BUCKET_PATH/$APP/$DATABASE/$FINAL_FILE_NAME --sse AES256


#Save data on Glacier vault
echo "-----> Archive description: $FINAL_FILE_NAME" 
/tmp/aws/bin/aws glacier upload-archive --archive-description $FINAL_FILE_NAME \
  --account-id -  \
  --vault-name $VCO_BACKUPS_VAULT_NAME \
  --body FINAL_FILE_NAME 

