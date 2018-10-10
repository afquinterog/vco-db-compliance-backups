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

if [[ -z "$VCO_BACKUPS_SNS_TOPIC" ]]; then
  echo "Missing VCO_BACKUPS_SNS_TOPIC variable which must be set to the AWS SNS topic for notifications"
  exit 1
fi

if [ "$(date +%u)" = 1 ]; then 

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


	echo "-----> Compress backup .... "
	tar -czPf /tmp/backup.tgz $FINAL_FILE_NAME > /dev/null

	echo "-----> backing up to glacier .... "

	#Save data on Glacier vault
	echo "-----> Archive description: $FINAL_FILE_NAME" 
	/tmp/aws/bin/aws glacier upload-archive --archive-description $FINAL_FILE_NAME \
	  --account-id -  \
	  --vault-name $VCO_BACKUPS_VAULT_NAME \
	  --body /tmp/backup.tgz 

	#notify the sns topic
	/tmp/aws/bin/aws sns publish --topic-arn "$VCO_BACKUPS_SNS_TOPIC" \
	 	--message "A new database backup has been generated for the $APP and has been sent to glacier."
	 	
else
	echo "-----> Backups will run once a week .... "	
fi



