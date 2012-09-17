# !/bin/bash
# Script that performs silent installation of IAM. Prerequisites are installed and configured Oracle database, and configured Linux OS. The script loads database schemas, installs WLS, installs SOA and IAM Suites. The script does not configure products since WLS domain creation must be done in GUI mode (for time being). After domain creation, remaining configuration is done with silentConfig.sh. 
# NOTE: Patches for OIM as described in Release Notes and Bug 1448975 are not applied.
#

# Utility function that logs responses to command window and log file "install.log"
#
function logevent {	
	if [ "$1" == "date" ]
    then
		echo
		date
		echo >> install.log
		date >> install.log
	else
		echo
		echo $1
		echo >> install.log
		echo $1 >> install.log
	fi
}

# Function that loads necessary database schemas to Oracle database with Oracle RCU. Remember to add to the command all the components that are listed in parameter file. Remember also that the order of passwords in the password file is relevant to the order of the components getting installed.
# 
function loaddbschemas {
	logevent "Loading database schmeas with Oracle RCU."
	$RCU_INSTALL_DIR/rcuHome/bin/rcu -silent -createRepository -databaseType ORACLE -connectString $DB_CONN_STRING -dbUser $DB_USER -dbRole $DB_ROLE -selectDependentsForComponents true -schemaPrefix $SCHEMA_PREFIX -component $COMP_1 -component $COMP_2 -f < $PWD_FILE >> install.log
	if [ "$?" == "0" ]
	then
		logevent "Successfully loaded database schemas."
		logevent "Removing password file."
		rm passwordfile.txt
	else
		logevent "Unknown error occurred loading database schemas."
	fi
}

# Function than installs Oracle WebLogic Server which is a prerequisite for both Oracle SOA and IAM Suites.
#
function installwls {
	logevent "Installing Oracle WLS."
	java -Xmx1024m -d64 -jar $WLS_INSTALL_DIR/wls1036_generic.jar -mode=silent -silent_xml=$SILENT_FILE -log=install.log
	if [ "$?" == "0" ]
	then
		logevent "Successfully finished installation of WLS."
	elif [ "$?" == "-1" ]
	then
		logevent "Installation failed due to a fatal error."
	elif [ "$?" == "-2" ]
	then
		logevent "Installation failed due to an internal XML parsing error."
	else
		logevent "Unknown error occurred installing Oracle WLS."
	fi
}

# Function that installs Oracle SOA Suite.
#
function installsoa {
	logevent "Installing Oracle SOA Suite."
	$SOA_INSTALL_DIR/Disk1/runInstaller -jreLoc $JAVA_HOME -silent -responseFile $SCRIPT_DIR/soa_install_only.rsp -logLevel $LOG_LEVEL -debug >> install.log
	if [ "$?" == "0" ]
	then
		while [ $(pgrep -f $SOA_INSTALL_DIR) ]
		do
			sleep 5
		done
		logevent "Successfully finished installation of Oracle SOA Suite."
	else
		logevent "Unknown error occurred installing Oracle SOA Suite."
	fi
}

# Function that installs Oracle IAM Suite.
#
function installiam {
	logevent "Installing Oracle IAM Suite."
	$IAM_INSTALL_DIR/Disk1/runInstaller -jreLoc $JAVA_HOME -silent -responseFile $SCRIPT_DIR/iam_install_only.rsp -logLevel $LOG_LEVEL -debug >> install.log
	if [ "$?" == "0" ]
	then
		while [ $(pgrep -f $IAM_INSTALL_DIR) ]
		do
			sleep 5
		done
		logevent "Successfully finished installation of Oracle IAM Suite."
	else
		logevent "Unknown error occurred installing Oracle IAM Suite."
	fi
}


# Starting the installation process. First create the log file and write some output to log. Then we initialize environment parameters. Following is the series of operations where runing depends on the result of the previous operation. Eg. SOA Suite is only installed if WLS installation is successful. 
#
echo This is installation log of Oracle IAM. > install.log
echo
echo For details of silent installation process, see log file install.log
logevent "Starting silent installation of Oracle IAM."
logevent date

# Initialize the environment by setting the necessary parameters
#
. ./environment.params

# Load database schemas.
#
loaddbschemas
if [ "$?" == "0" ]
then	 
	# Install WLS.
	#
	installwls
	if [ "$?" == "0" ]
	then
		# Install SOA Suite.
		#
		installsoa
		if [ "$?" == "0" ]
		then
			# Install IAM Suite.
			#
			installiam
			if [ "$?" == "0" ]
			then
				logevent "Finished silent installation of Oracle IAM."
				logevent date
			fi
		fi
	fi
fi
