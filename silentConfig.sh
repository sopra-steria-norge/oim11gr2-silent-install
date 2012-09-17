# !/bin/bash
# Script that performs silent configuration of IAM. Prerequisites are installed and configured Oracle database, configured Linux OS, installed products and created WLS domain. The script configures Database Security Store and configures products. Installing products is done with silentInstall.sh and domain creation is done in GUI mode.
#

# Utility function that logs responses to command window and log file "config.log"
#
function logevent {	
	if [ "$1" == "date" ]
    then
		echo
		date
		echo >> config.log
		date >> config.log
	else
		echo
		echo $1
		echo >> config.log
		echo $1 >> config.log
	fi
}

# Function that configures Database Security Store. It differentiates between "create" and "join" mode.
# NOTE: When using the "join" mode, use absolute paths instead of environment variables. Otherwise, the script fails to create policy store objects. This is a bug.
#
function confdbsecstore {
	if [ "$DSS_MODE" == "create" ]
	then
		logevent "Creating and configuring Database Security Store."
		$MW_HOME/oracle_common/common/bin/wlst.sh $IAM_HOME/common/tools/configureSecurityStore.py -d $WLS_DOMAIN_DIR -c IAM -p $OPSS_PWD -m create >> config.log
		$MW_HOME/oracle_common/common/bin/wlst.sh $IAM_HOME/common/tools/configureSecurityStore.py -d $WLS_DOMAIN_DIR -m validate >> config.log
	elif [ "$DSS_MODE" == "join" ]
	then
		logevent "Joning a new domain to existing Database Security Store."
		echo 'exportEncryptionKey(jpsConfigFile="$WLS_DOMAIN_DIR/config/fmwconfig/jps-config.xml", keyFilePath="$SCRIPT_DIR", keyFilePassword="$KEY_PWD_FILE")' > encKeyCmd.py
		$MW_HOME/oracle_common/common/bin/wlst.sh encKeyCmd.py >> config.log
		/oracle/mdw/oracle_common/common/bin/wlst.sh /oracle/mdw/iam/common/tools/configureSecurityStore.py -d /oracle/mdw -c IAM -p $OPSS_PWD -m join -k $SCRIPT_DIR -w $KEY_PWD_FILE >> config.log
		$MW_HOME/oracle_common/common/bin/wlst.sh $IAM_HOME/common/tools/configureSecurityStore.py -d $WLS_DOMAIN_DIR -m validate >> config.log
		rm encKeyCmd.py		
	fi
}

# Function that starts an instance of WLS Server, either Admin og Managed. The input parameter is the name of the server.
#
function startserver {
	if [ "$1" == "AdminServer" ]
	then
		logevent "Starting WLS Administration Server."
		$WLS_DOMAIN_DIR/startWebLogic.sh >> config.log &
		$MW_HOME/oracle_common/common/bin/wlst.sh $SCRIPT_DIR/checkServerState.py $1 $WLS_ADMIN_USER $WLS_ADMIN_PWD >> config.log
	else
		logevent "Starting WLS Managed Server: $1"
		$WLS_DOMAIN_DIR/bin/startManagedWebLogic.sh $1 >> config.log &
		$MW_HOME/oracle_common/common/bin/wlst.sh $SCRIPT_DIR/checkServerState.py $1 $WLS_ADMIN_USER $WLS_ADMIN_PWD >> config.log
	fi
}

# Function that configures OIM Server based on the input response file.
#
function configureoimserver {
	logevent "Configuring OIM Server."
	$IAM_HOME/bin/config.sh -jreLoc $JAVA_HOME -silent -responseFile $SCRIPT_DIR/iam_config_only.rsp -logLevel $LOG_LEVEL -debug >> config.log
}


# Starting the configuration process. First create the log file and write some output to log. Then we initialize environment parameters. Following is the series of operations where runing depends on the result of the previous operation. 
#
echo This is configuration log of Oracle IAM. > config.log
echo
echo For details of silent configuration process, see log file config.log
logevent "Starting silent configuration of Oracle IAM."
logevent date

# Initialize the environment by setting the necessary parameters
#
. ./environment.params


if [ "$DSS_MODE" == "create" ]
then
	# Configure Database Security Store.
	#
	confdbsecstore
	if [ "$?" == "0" ]
	then
		logevent "Successfully created and configured Database Security Store."
		# Start WLS Admin Server
		#
		startserver "AdminServer"
		if [ "$?" == "0" ]
		then
			logevent "Successfully started WLS Administration Server."
			# Configure OIM Server
			#
			configureoimserver
			if [ "$?" == "0" ]
			then		
				logevent "Successfully finished configuration of OIM Server."
				# Start SOA Server.
				#
				startserver "soa_server1"
				if [ "$?" == "0" ]
				then
					logevent "Successfully started WLS Managed Server: soa_server1."
					# Start OIM Server.
					#
					startserver "oim_server1"					
					if [ "$?" == "0" ]
					then
						logevent "Successfully started WLS Managed Server: oim_server1."
					else
						"WLS Managed Server oim_server1, did not start due to an unknown error."
					fi
				else
					logevent "WLS Managed Server soa_server1, did not start due to an unknown error."
				fi
			else
				logevent "Unknown error occurred configuring OIM Server."
			fi
		else
			logevent "WLS Administration Server did not start due to an unknown error."
		fi
	else
		logevent "Error during creation and configuration of Database Security Store."
	fi
elif [ "$DSS_MODE" == "join" ]
then
	# Configure Database Security Store.
	#
	confdbsecstore
	if [ "$?" == "0" ]
	then
		logevent "Successfully joined the domain to the Database Security Store."
		# Start WLS Admin Server
		#
		startserver "AdminServer"
		if [ "$?" == "0" ]
		then
			logevent "Successfully started WLS Administration Server."
			# Configure OIM Server
			#
			configureoimserver
			if [ "$?" == "0" ]
			then		
				logevent "Successfully finished configuration of OIM Server."
				# Start SOA Server.
				#
				startserver "soa_server1"
				if [ "$?" == "0" ]
				then
					logevent "Successfully started WLS Managed Server: soa_server1."
					# Start OIM Server.
					#
					startserver "oim_server1"					
					if [ "$?" == "0" ]
					then
						logevent "Successfully started WLS Managed Server: oim_server1."
					else
						"WLS Managed Server oim_server1, did not start due to an unknown error."
					fi
				else
					logevent "WLS Managed Server soa_server1, did not start due to an unknown error."
				fi
			else
				logevent "Unknown error occurred configuring OIM Server."
			fi
		else
			logevent "WLS Administration Server did not start due to an unknown error."
		fi
	else
		logevent "Error during joining the domain to the Database Security Store."
	fi
else
	logevent "Value of DSS_MODE in environment.params is wrong."
fi
