#!/bin/bash
echo -e "#!/bin/bash\nsleep 60\nreboot\n" > /tmp/rebooter.sh
chmod 777 /tmp/rebooter.sh
#the following line un-does the writting of the versions file in the overlay "user"
#We need info to perform correctly and this corrects the old way it used to work
rm -rf /mnt/.overlay/user/slash/wigwag/etc/versions.json
/tmp/rebooter.sh &

