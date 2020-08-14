#!/bin/sh
####################################################
# drive.sh   : google drive rest api usage
# Usage      : sh drive.sh &
#
# Todo List  :
#
# Date       : 10/06/2017
# Author     : Mehmet Rıza ÖZ @ Vestel
#####################################################

# Google Drive API

get_file_id() {
	RESPONSE=`curl --silent -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files?q=title+contains+\'$1\'\&fields=items%2Fid`
	FILE_ID=`echo $RESPONSE | python -mjson.tool | grep -oP 'id"\s*:\s*"\K(.*)"' | sed 's/"//'`
}

set -e

CLIENT_SECRET="89vhQG-VKaCyV0tf_uLttQ3M"
CLIENT_ID="857131469426-knedno1ikclf35tt308gp4qb1cm68o91.apps.googleusercontent.com"
BOUNDARY="foo_bar_baz"
SCOPE="https://docs.google.com/feeds"
MIME_TYPE="application/octet-stream"
ACCESS_TOKEN=`cat access_token`
REFRESH_TOKEN=`cat refresh_token`
FOLDER_ID=`cat folder_id`

if [ "$1" == "create_token" ]; then # Usage: <"create_token">
	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/device/code" -d "client_id=$CLIENT_ID&scope=$SCOPE"`
	DEVICE_CODE=`echo "$RESPONSE" | python -mjson.tool | grep -oP 'device_code"\s*:\s*"\K(.*)"' | sed 's/"//'`
	USER_CODE=`echo "$RESPONSE" | python -mjson.tool | grep -oP 'user_code"\s*:\s*"\K(.*)"' | sed 's/"//'`
	URL=`echo "$RESPONSE" | python -mjson.tool | grep -oP 'verification_url"\s*:\s*"\K(.*)"' | sed 's/"//'`
	echo -n "Go to $URL and enter $USER_CODE to grant access to this application. Hit enter when done..."
	read

	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&code=$DEVICE_CODE&grant_type=http://oauth.net/grant_type/device/1.0"`
	ACCESS_TOKEN=`echo "$RESPONSE" | python -mjson.tool | grep -oP 'access_token"\s*:\s*"\K(.*)"' | sed 's/"//'`
	REFRESH_TOKEN=`echo "$RESPONSE" | python -mjson.tool | grep -oP 'refresh_token"\s*:\s*"\K(.*)"' | sed 's/"//'`
	echo "Access Token: $ACCESS_TOKEN"
	echo "Refresh Token: $REFRESH_TOKEN"
	echo "$ACCESS_TOKEN" > access_token
	echo "$REFRESH_TOKEN" > refresh_token

elif [ "$1" == "refresh_token" ]; then # Usage: <"refresh_token">
	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token"`
	ACCESS_TOKEN=`echo $RESPONSE | python -mjson.tool | grep -oP 'access_token"\s*:\s*"\K(.*)"' | sed 's/"//'`	
	echo "Access Token: $ACCESS_TOKEN"	
        echo "$ACCESS_TOKEN" > access_token

elif [ "$1" == "create_folder" ]; then # Usage: <"create_folder">
	FOLDER_NAME=`date "+%F-%T"`
	( echo -en "{ \"title\": \"$FOLDER_NAME\", \"mimeType\": \"application/vnd.google-apps.folder\" }\n" ) \
		| curl -H 'GData-Version: 3.0' -v "https://www.googleapis.com/drive/v2/files" \
		--header "Authorization: Bearer $ACCESS_TOKEN" \
		--header "Content-Type: application/json" \
		--data-binary "@-"
	#save FILE_ID to filde
	get_file_id $FOLDER_NAME
	echo "$FILE_ID" > folder_id

elif [ "$1" == "upload_file" ]; then # Usage: <"upload_file"> <file name>
	( echo -en "--$BOUNDARY\nContent-Type: application/json; charset=UTF-8\n\n{ \"title\": \"$2\", \"parents\": [ { \"id\": \"$FOLDER_ID\" } ] }\n\n--$BOUNDARY\nContent-Type: $MIME_TYPE\n\n" \
	&& cat $2 && echo -en "\n\n--$BOUNDARY--\n" ) \
		| curl -H 'GData-Version: 3.0' -v "https://www.googleapis.com/upload/drive/v2/files/?uploadType=multipart" \
		--header "Authorization: Bearer $ACCESS_TOKEN" \
		--header "Content-Type: multipart/related; boundary=\"$BOUNDARY\"" \
		--data-binary "@-"

elif [ "$1" == "list_files" ]; then # Usage: <"list_files"> <number of files>
	curl -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files?maxResults=$2

elif [ "$1" == "download_file" ]; then # Usage: <"download_file"> <file name>
	get_file_id $2
	curl -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files/$FILE_ID?alt=media

elif [ "$1" == "get_file" ]; then # Usage: <"get_file"> <file name> 
	get_file_id $2
	curl -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files/$FILE_ID

elif [ "$1" == "delete_file" ]; then # Usage: <"delete_file"> <file name>
	get_file_id $2
	curl -X Delete -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files/$FILE_ID

elif [ "$1" == "trash_file" ]; then # Usage: <"trash_file"> <file name>
	get_file_id $2
	curl -d -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files/$FILE_ID/trash

elif [ "$1" == "untrash_file" ]; then # Usage: <"untrash_file"> <file name>
	get_file_id $2
	curl -d -H 'GData-Version: 3.0' -H "Authorization: Bearer $ACCESS_TOKEN" \
		https://www.googleapis.com/drive/v2/files/$FILE_ID/untrash
fi

exit 0

