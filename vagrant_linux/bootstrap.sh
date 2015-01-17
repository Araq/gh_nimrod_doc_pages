#!/usr/bin/env bash

# Test zip command.
echo "Checking installation of zip command."
zip | grep Copyright
if [ $? != 0 ]; then
	apt-get update
	apt-get install -y zip
else
	echo "Seems to be installed, not updating."
fi
