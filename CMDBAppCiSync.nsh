#!/bin/nsh
#
#######################################################################
#<doc>	NAME
#<doc>		CMDBAppCiSync.nsh
#<doc>	DESCRIPTION:
#<doc>		Sync CBS base card files
#<doc>	SCRIPT TYPE:
#<doc>		NSH Script 
#<doc>			#2 - Execute the script one, passing the host list as a parameter to the script.
#<doc>			Allow run with no targets - is checked.
#<doc>	SYNTAX:
#<doc>		CMDBAppCiSync.nsh
#<doc>	DIAGNOSTICS:
#<doc>		Exit code 0 if successful
#<doc>		Exit code 1 on failure
#<doc>		Exit code 2 on failure in process but not in full script.
#<doc>	OWNER:
#<doc>		Copyright (C) 2018 ZB, N.A.
########################################################################
#	DATE		MODIFIED BY		REASON FOR & DESCRIPTION OF MODIFICATION
#	--------	-------------	----------------------------------------
#	07/06/2011	Craig Ludlow	Written
#	03/14/2017	Frank Brand		Re-Written
#	08/30/2018	Frank Brand		Major changes :-)
########################################################################
#	Init variables

TARGET=//@																		## Denotes local BL APP Server where script is ran.
WORK_PATH="storage/bladmintmp/CMDB"												## The default working path.
TIME_STAMP=`date '+%Y%m%d_%H%M'`												## date '+%m-%d-%Y %H:%M:%S'
DEBUG=1																	# "1"	## Debug 1=ON 0=OFF
EXIT_CODE=0																# "0"	## Default EXIT_CODE=0
#TEST_LETTER=Z

# Work files
BL_CMDB_APPS="${TARGET}/${WORK_PATH}/BL_CMDB_Apps.csv"							## The output of the BladeLogic CMDB_Applications data.
BL_CMDB_APP_LIST="${TARGET}/${WORK_PATH}/BL_CMDB_App_List.csv"					## CMDB Application list from BladeLogic.
BL_CMDB_DEPRECATED="${TARGET}/${WORK_PATH}/BL_CMDB_Deprecated.csv"				## The output of the BladeLogic CMDB_Applications data.
BL_CMDB_DELETE_APP="${TARGET}/${WORK_PATH}/BL_CMDB_Delete_App.csv"				## BladeLogic CMDB Instances that need to be deleted.
BL_CMDB_NEW="${TARGET}/${WORK_PATH}/BL_CMDB_New.csv"							## CMDB Application list from BladeLogic.
BL_CMDB_UPDATE="${TARGET}/${WORK_PATH}/BL_CMDB_update.csv"						## All property instances needing updates.
BL_NEED_FIXING="${TARGET}/${WORK_PATH}/BL_Need_Fixing.csv"						## CMDB Application list from BladeLogic.
CMDB_FILE="${TARGET}/${WORK_PATH}/CMDB_master.csv"								## A cleaned up copy of the CMDB data dump.
CMDB_FIX="${TARGET}/${WORK_PATH}/CMDB_fix.csv"									## A list of errors found from the BladeLogic output
CMDB_LOG="${TARGET}/${WORK_PATH}/CMDB_${TIME_STAMP}.log"						## Errors found while trying to extract "$APP,$CIID,$CMDB_NAME,$COST_CENTER" data.  //blfs/storage/bladmintmp/CMDB/logs/CMDB_20181123_0937.log
TEMP_FILE_1="${TARGET}/${WORK_PATH}/CMDB_temp1.csv"								## A file used when cleaning up data.
TEMP_FILE_2="${TARGET}/${WORK_PATH}/CMDB_temp2.csv"								## A file used when cleaning up data.
CMDB_DUMP="//utmsfs09/d/Service_Desk/CMDB/CMDBApplicationsForBladeLogic.csv"	## Location of CMDB dump file"

### OLD Properties
#CMDB_ADD="${TARGET}/${WORK_PATH}/CMDB_add.csv"									## Records that need to be added to BladeLogic.
#CMDB_UPDATE_NAME="${TARGET}/${WORK_PATH}/CMDB_up_name.csv"						## The Name of the property instance.
#CMDB_UPDATE_CMDBNAME="${TARGET}/${WORK_PATH}/CMDB_up_cmdbname.csv"				## The Name of the property instance.
#CMDB_UPDATE_COST="${TARGET}/${WORK_PATH}/CMDB_up_cost.csv"						## The Name of the property instance.
#CMDB_APP="//blfs/${WORK_PATH}/CMDB_Application.csv"							## File used to update Server Add Form.

#	END Init variables
########################################################################

ApplyUpdates ()
	{
	log_header_output ApplyUpdates | tee -a ${CMDB_LOG}
	if test -f ${BL_CMDB_UPDATE}; then
			UPDATES=`wc ${BL_CMDB_UPDATE} | awk '{ print $1 }'`
			debug "UPDATES >> ${UPDATES}" | tee -a ${CMDB_LOG}
			if [ "${UPDATES}" -gt "0" ]; then
					blcli_execute PropertyInstance bulkSetPropertyValues "/${WORK_PATH}" "BL_CMDB_update.csv" #>/dev/null 2>/dev/null
					if test $? = 0; then
							echo "The following changes were made:" | tee -a ${CMDB_LOG}
							cat ${BL_CMDB_UPDATE} | tee -a ${CMDB_LOG}
						else
							echo "ERROR: No changes were made when ApplyUpdates was ran." | tee -a ${CMDB_LOG}
							EXIT_CODE=1
					fi
				else
					echo "There were no updates to be applied." | tee -a ${CMDB_LOG}
			fi
		else
			echo "There were no updates to be applied." | tee -a ${CMDB_LOG}
	fi	
	}

BlPullCmdbAppData ()
	{
	#######
	## INFO - Pulls the details for each CMDB Application in the "BL_CMDB_APP_LIST".
	#######
	log_header_output BlPullCmdbAppData | tee -a ${CMDB_LOG}
#	FileCleanup ${BL_CMDB_APPS}
#	FileCleanup ${TEMP_FILE_1}
	COUNT=`wc ${BL_CMDB_APP_LIST} | awk '{ print $1 }'`
	APPS=`cat ${BL_CMDB_APP_LIST}`
	for APP in $APPS
		do
			blcli PropertyInstance listAllFullyResolvedPropertyValues "$APP" > ${TEMP_FILE_1}
			if test $? = 0; then
					CIID=`cat ${TEMP_FILE_1} | grep ^CMDB_CIID | sed 's/CMDB_CIID\ =\ //g'`
						if test ! "${CIID}"; then
								CIID=Unknown
						fi
					CMDB_NAME=`cat ${TEMP_FILE_1} | grep ^CMDB_Name | sed 's/CMDB_Name\ =\ //g'`
						if test ! "${CMDB_NAME}"; then
								CMDB_NAME=Unknown
						fi
					CONTACT=`cat ${TEMP_FILE_1} | grep ^APP_OWNER | sed 's/APP_OWNER\ =\ //g'`
						if test ! "${CONTACT}"; then
								CONTACT=Unknown
						fi
					COST_CENTER=`cat ${TEMP_FILE_1} | grep Cost_Center | sed 's/Cost_Center\ =\ //g'`
						if test ! "${COST_CENTER}"; then
								COST_CENTER=Unknown
						fi
					DESCRIPTION=`cat ${TEMP_FILE_1} | grep ^DESCRIPTION | sed 's/DESCRIPTION\ =\ //g'`
						if test ! "${DESCRIPTION}"; then
								DESCRIPTION=Unknown
						fi
					NAME=`cat ${TEMP_FILE_1} | grep ^NAME | sed 's/NAME\ =\ //g'`
						if test ! "${NAME}"; then
								NAME=Unknown
						fi
				else
					echo "ERROR: NO APP Data Found for ${APP}!" | tee -a ${CMDB_LOG}
					CIID="NO CMDB_Application DATA FOUND"
					CMDB_NAME="NO CMDB_Application DATA FOUND"
					CONTACT="NO CMDB_Application DATA FOUND"
					COST_CENTER="NO CMDB_Application DATA FOUND"
					DESCRIPTION="NO CMDB_Application DATA FOUND"
					NAME="NO CMDB_Application DATA FOUND"
					EXIT_CODE=2
			fi
			echo "${COUNT} - \"$CIID\",\"$CMDB_NAME\",\"$COST_CENTER\",\"$CONTACT\",\"$NAME\",\"$DESCRIPTION\"" | tee -a ${CMDB_LOG}
			echo "\"$CIID\",\"$CMDB_NAME\",\"$COST_CENTER\",\"$CONTACT\",\"$NAME\",\"$DESCRIPTION\"" >> ${BL_CMDB_APPS}
			COUNT=`expr ${COUNT} - 1`
		done
	echo "\"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\",\"Branch Servers\",\"1081020\",\"Cliff Bates\",\"BRANCH_SERVERS\"" >> ${BL_CMDB_APPS}
	mv ${BL_CMDB_APPS} ${TEMP_FILE_1}
	cat ${TEMP_FILE_1} | grep -v "NO CMDB_Application DATA FOUND" > ${BL_CMDB_APPS}

	# FileCleanup ${TEMP_FILE_1}
	}

BlPullCmdbLists ()
	{
	#######
	## INFO - Pulls the list of "Fully Qualified Class Instance Name" from BladeLogic.
	#######
	log_header_output BlPullCmdbLists | tee -a ${CMDB_LOG}
	FileCleanup ${BL_CMDB_APP_LIST}
	echo "Pulling CMDB_Application list from BladeLogic Database." | tee -a ${CMDB_LOG}
	blcli PropertyClass listAllInstanceNames Class://SystemObject/CMDB_Application > ${TEMP_FILE_1}
	if test $? -eq 0; then
#			cat ${TEMP_FILE_1} | grep -v "DEPRECATED" | grep -v NO_APPLICATION_LISTED | grep -v BRANCH_SERVERS| grep Class://SystemObject/CMDB_Application/${TEST_LETTER} | sort | uniq > ${BL_CMDB_APP_LIST}
			cat ${TEMP_FILE_1} | grep -v "DEPRECATED" | grep -v NO_APPLICATION_LISTED | grep -v BRANCH_SERVERS | sort | uniq > ${BL_CMDB_APP_LIST}
		else
			echo "ERROR: The following BLCLI Command Failed:\nblcli PropertyClass listAllInstanceNames Class://SystemObject/CMDB_Application" | tee -a ${CMDB_LOG}
			exit 1
	fi
	}

BlRemoveDeprecated ()
	{
	#######
	## INFO - Remove all depricated CMDN Applications from the "BL_CMDB_APP_LIST".
	#######
	log_header_output BlRemoveDeprecated | tee -a ${CMDB_LOG}
	FileCleanup ${TEMP_FILE_1}
#	cat //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv | sed '/^$/d' | tr -d $'\r' | grep "CMDB_Application/${TEST_LETTER}"| sort | uniq > ${BL_CMDB_DEPRECATED}
	cat //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv | sed '/^$/d' | tr -d $'\r' | sort | uniq > ${BL_CMDB_DEPRECATED}
	DEP_LIST=`cat ${BL_CMDB_DEPRECATED}`
	COUNT=`wc ${BL_CMDB_DEPRECATED} | awk '{ print $1 }'`
	for LINE in ${DEP_LIST}
	do
		echo "${COUNT} - ${LINE}" | tee -a ${CMDB_LOG}
		cat ${BL_CMDB_APP_LIST} | grep -v "${LINE}" > ${TEMP_FILE_1}
		cat ${TEMP_FILE_1} | sort | uniq > ${BL_CMDB_APP_LIST}
		COUNT=`expr ${COUNT} - 1`
	done
	# FileCleanup  ${TEMP_FILE_1}
	}

CheckAppData ()
	{
	#######
	## INFO - Compare CMDB data with the BL application data.  If data does not match then the CMDB data is applied to BL.
	#######
	log_header_output CheckAppData | tee -a ${CMDB_LOG}
	FileCleanup  ${BL_CMDB_NEW}
	COUNT=`wc ${CMDB_FILE} | awk '{ print $1 }'`
	APPS=`cat ${CMDB_FILE} | sed 's/\",\"/    /g' | sed 's/\"//g' | awk '{ print $1 }'`
	for APP in $APPS
		do
			BL_NAME_LOWER=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $2 }' | sed 's/_/ /g'`
			CMDB_NAME_LOWER=`cat ${CMDB_FILE} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $2 }' | sed 's/_/ /g'`
			BL_COSTCENTER=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $3 }'`
			CMDB_COSTCENTER=`cat ${CMDB_FILE} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $3 }'`
			BL_APP_NAME=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $5 }'`
			CMDB_NAME=`cat ${CMDB_FILE} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $5 }'`
			BL_APP_OWNER=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $4 }' | sed 's/_/ /g'`	
			CMDB_OWNER=`cat ${CMDB_FILE} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $4 }' | sed 's/_/ /g'`
			BL_APP_DESC=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $6 }' | sed 's/_/ /g'`
			CMDB_DESC="${CMDB_NAME_LOWER} - ${CMDB_COSTCENTER}"

			echo "${COUNT} - ${CMDB_NAME}" | tee -a ${CMDB_LOG}
			debug "\tAPP             >> ${APP}" >> ${CMDB_LOG}
			debug "\tBL_NAME_LOWER   >> ${BL_NAME_LOWER}\n\tCMDB_NAME_LOWER >> ${CMDB_NAME_LOWER}" >> ${CMDB_LOG}
			debug "\tBL_COSTCENTER   >> ${BL_COSTCENTER}\n\tCMDB_COSTCENTER >> ${CMDB_COSTCENTER}" >> ${CMDB_LOG}
			debug "\tBL_APP_NAME     >> ${BL_APP_NAME}\n\tCMDB_NAME       >> ${CMDB_NAME}" >> ${CMDB_LOG}
			debug "\tBL_APP_OWNER    >> ${BL_APP_OWNER}\n\tCMDB_OWNER      >> ${CMDB_OWNER}" >> ${CMDB_LOG}
			debug "\tBL_APP_DESC     >> ${BL_APP_DESC}\n\tCMDB_DESC       >> ${CMDB_DESC}" >> ${CMDB_LOG}
			if [ -z ${BL_APP_NAME} ]; then
#			if ! test ${BL_APP_NAME}; then
					cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | sed 's/~//g' | awk '{ print $5 }'
					echo "\t\"${CMDB_NAME}\" is a new Application CI." | tee -a ${CMDB_LOG}
					debug "\t\"${APP}\",\"${CMDB_NAME_LOWER}\",\"${CMDB_COSTCENTER}\",\"${CMDB_NAME}\",\"${CMDB_OWNER}\",\"${CMDB_DESC}\"\n" | tee -a ${CMDB_LOG}
					echo "\"${APP}\",\"${CMDB_NAME_LOWER}\",\"${CMDB_COSTCENTER}\",\"${CMDB_NAME}\",\"${CMDB_OWNER}\",\"${CMDB_DESC}\"" >> ${BL_CMDB_NEW}
		##  Add process for NEW Application Instances.
		##	Add process to check for NEW Application Instances in the Depricated list.  Remove from list if found.
				else
					if ! [ "${CMDB_DESC}" = "${BL_APP_DESC}" ]; then
							echo "\tINFO: Application Descriptions do not match." | tee -a ${CMDB_LOG}
			#				debug "\t\tBL_APP_DESC >> ${BL_APP_DESC}\n\t\tCMDB_DESC >> ${CMDB_DESC}" >> ${CMDB_LOG}
							echo "\t\tOld Descreiption  >> ${BL_APP_DESC}" | tee -a ${CMDB_LOG}
							echo "\t\tNew Descreiption >> ${CMDB_DESC}" | tee -a ${CMDB_LOG}
			#				echo "\"Class://SystemObject/CMDB_Application/${BL_APP_NAME}\",\"DESCRIPTION\",\"${CMDB_DESC}\"" >> ${BL_CMDB_UPDATE}
							UpdateAppInstanceName Class://SystemObject/CMDB_Application/${BL_APP_NAME} setDescription "${CMDB_DESC}"
						else
							debug "\tINFO: Application Descriptions looks good." >> ${CMDB_LOG}
					fi

					if ! [ "${CMDB_NAME}" = "${BL_APP_NAME}" ]; then
							echo "\tINFO: Application names do not match." | tee -a ${CMDB_LOG}
			#				debug "\t\tBL_APP_NAME >> ${BL_APP_NAME}\n\t\tCMDB_NAME >> ${CMDB_NAME}" | tee -a ${CMDB_LOG}
							echo "\t\tOld Application Name = \"${BL_APP_NAME}\"" | tee -a ${CMDB_LOG}
							echo "\t\tNew Application Name = \"${CMDB_NAME}\"" | tee -a ${CMDB_LOG}
			#				echo "\"Class://SystemObject/CMDB_Application/${CMDB_NAME}\",\"CMDB_Name\",\"${CMDB_NAME}\"" >> ${BL_CMDB_UPDATE}
							echo "\"Class://SystemObject/CMDB_Application/${CMDB_NAME}\",\"SSA_Name\",\"${CMDB_NAME}\"" >> ${BL_CMDB_UPDATE}
			#				echo "EXECUTING: UpdateAppInstanceName Class://SystemObject/CMDB_Application/${BL_APP_NAME} setName \"${CMDB_NAME}\""
							UpdateAppInstanceName Class://SystemObject/CMDB_Application/${BL_APP_NAME} setName "${CMDB_NAME}"
						else
							debug "\tINFO: Application names looks good." >> ${CMDB_LOG}
					fi

					if ! [ "${CMDB_COSTCENTER}" = "${BL_COSTCENTER}" ]; then
							echo "\tINFO: Cost centers do not match." | tee -a ${CMDB_LOG}
			#				debug "\t\tBL_COSTCENTER >> ${BL_COSTCENTER}\n\t\tCMDB_COSTCENTER >> ${CMDB_COSTCENTER}" >> ${CMDB_LOG}
							echo "\t\tOld Cost_Center >> ${BL_COSTCENTER}" | tee -a ${CMDB_LOG}
							echo "\t\tNew Cost_Center >> ${CMDB_COSTCENTER}" | tee -a ${CMDB_LOG}
							echo "\"Class://SystemObject/CMDB_Application/${CMDB_NAME}\",\"Cost_Center\",\"${CMDB_COSTCENTER}\"" >> ${BL_CMDB_UPDATE}
						else
							debug "\tINFO: Cost centers looks good." >> ${CMDB_LOG}
					fi

					if ! [ "${CMDB_OWNER}" = "${BL_APP_OWNER}" ]; then
							echo "\tINFO: Application Owners do not match." | tee -a ${CMDB_LOG}
			#				debug "\t\tBL_APP_OWNER >> ${BL_APP_OWNER}\n\t\tCMDB_OWNER >> ${CMDB_OWNER}" >> ${CMDB_LOG}
							echo "\t\tOld Owner = \"${BL_APP_OWNER}\"" | tee -a ${CMDB_LOG}
							echo "\t\tNew Owner = \"${CMDB_OWNER}\"" | tee -a ${CMDB_LOG}
							echo "\"Class://SystemObject/CMDB_Application/${CMDB_NAME}\",\"APP_OWNER\",\"${CMDB_OWNER}\"" >> ${BL_CMDB_UPDATE}
						else
							debug "\tINFO: Owners names looks good." >> ${CMDB_LOG}
					fi

					if ! [ "${CMDB_NAME_LOWER}" = "${BL_NAME_LOWER}" ]; then
							echo "\tINFO: CMDB Names do not match." | tee -a ${CMDB_LOG}
			#				debug "\t\tBL_APP_OWNER >> ${BL_NAME_LOWER}\n\t\tCMDB_OWNER >> ${CMDB_NAME_LOWER}" | tee -a ${CMDB_LOG}
							echo "\t\tOld CMDB Name = \"${BL_NAME_LOWER}\"" | tee -a ${CMDB_LOG}
							echo "\t\tNew CMDB Name = \"${CMDB_NAME_LOWER}\"" | tee -a ${CMDB_LOG}
							echo "\"Class://SystemObject/CMDB_Application/${CMDB_NAME}\",\"CMDB_Name\",\"${CMDB_NAME_LOWER}\"" >> ${BL_CMDB_UPDATE}
						else
							debug "\tINFO: CMDB names looks good." >> ${CMDB_LOG}
					fi
			fi
			COUNT=`expr ${COUNT} - 1`
		done
	}

CheckForDuplicateCiid ()
	{
	#######
	## INFO - 
	#######
	log_header_output CheckForDuplicateCiid | tee -a ${CMDB_LOG}
	APPS=`cat ${BL_CMDB_APPS} | sed 's/\",\"/    /g' | sed 's/\"//g' | awk '{ print $1 }'`
	for APP in $APPS
		do
			RESULTS=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $1 }' | uniq -c | awk '{ print $1}'`
			if test ${RESULTS} -eq 1; then
					echo "INFO: ${RESULTS} Application CIID was found for ${APP}." | tee -a ${CMDB_LOG}
				else
					echo "ERROR: CheckForDuplicateCiid found a duplicate CIID.  Need to finish the script." | tee -a ${CMDB_LOG}
					echo "APP >> ${APP}" | tee -a ${CMDB_LOG}
					cat ${BL_CMDB_APPS} | grep ${APP} | tee -a ${CMDB_LOG}
					exit 1
			fi
		done
	}

CmdbDataPrep ()
	{
	#######
	## INFO - Get data from the CMDB dump file and reformat it into a format that is easier to work with.
	#######
	log_header_output CmdbDataPrep | tee -a ${CMDB_LOG}
	touch ${CMDB_LOG}
	FileCleanup ${BL_CMDB_APPS}
	FileCleanup ${BL_CMDB_APP_LIST}
	FileCleanup ${BL_CMDB_DEPRECATED}
	FileCleanup ${BL_CMDB_DELETE_APP}
	FileCleanup ${BL_CMDB_NEW}
	FileCleanup ${BL_CMDB_UPDATE}
	FileCleanup ${BL_NEED_FIXING}
	FileCleanup ${CMDB_FILE}
	FileCleanup ${CMDB_FIX}
	FileCleanup ${TEMP_FILE_1}
	FileCleanup ${TEMP_FILE_2}
	
	if [ $DEBUG = "0" ]; then
			echo "\nDebug is OFF (0)\nLogfile >> ${CMDB_LOG}" | tee -a ${CMDB_LOG}
		else
			echo "\nDebug is ON (1)\nLogfile >> ${CMDB_LOG}" | tee -a ${CMDB_LOG}
	fi
	cp -v ${CMDB_DUMP} ${TARGET}/${WORK_PATH}/CMDB_Dump.csv | tee -a ${CMDB_LOG}
#	cat -v ${TARGET}/${WORK_PATH}/CMDB_Dump.csv | sort | grep ^\"${TEST_LETTER} | tr -d $'\r' | sed 's/M-^V/-/g' | sed 's/\//-/g' | grep -v "Reconciliation Identity" | sed 's/^\"//g' | awk -F '\",\"' '{print "\""$2 "\",\"" $1 "\",\"" $3 "\",\"" $4}' | sed 's/\"\"/\"Unknown\"/g' | sort  > ${TEMP_FILE_1}
	cat -v ${TARGET}/${WORK_PATH}/CMDB_Dump.csv | tr -d $'\r' | sed 's/M-^V/-/g' | sed 's/\//-/g' | grep -v "Reconciliation Identity" | sed 's/^\"//g' | awk -F '\",\"' '{print "\""$2 "\",\"" $1 "\",\"" $3 "\",\"" $4}' | sed 's/\"\"/\"Unknown\"/g' | sort  > ${TEMP_FILE_1}
	COUNT=`wc ${TEMP_FILE_1} | awk '{ print $1 }'`
	while IFS= read -r LINE
		do
			NAME=`echo "${LINE}" | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $2 }' | tr '[:lower:]' '[:upper:]'`
			echo "${COUNT} - ${LINE},\"${NAME}\"" | tee -a ${CMDB_LOG}
			echo "${LINE},\"${NAME}\"" >> ${CMDB_FILE}
			COUNT=`expr ${COUNT} - 1`
		done < "${TEMP_FILE_1}"
	echo "\"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\",\"Branch Servers\",\"1081020\",\"Cliff Bates\",\"BRANCH_SERVERS\"" >> ${CMDB_FILE}
	# FileCleanup  ${TEMP_FILE_1}
	# FileCleanup  ${TARGET}/${WORK_PATH}/CMDB_Dump.csv
	}
	
CreatNewCmdbInstance ()
	{
	#######
	## INFO - 
	#######
	log_header_output CreatNewCmdbInstance | tee -a ${CMDB_LOG}
	if test -f ${BL_CMDB_NEW}; then
		COUNT=`wc ${BL_CMDB_NEW} | awk '{ print $1 }'`
		NEW_APP_CI=`cat ${BL_CMDB_NEW} | sed 's/ /+^+/g'`
		for NEWCI in ${NEW_APP_CI}
			do
				debug "NEWCI       >> ${NEWCI}" | sed -e 's/+^+/ /g' >> ${CMDB_LOG}
				APP_OWNER=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $5}' | sed -e 's/+^+/ /g'`
				debug "APP_OWNER   >> ${APP_OWNER}" | tee -a ${CMDB_LOG}
				CMDB_CIID=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $1 }'`
				debug "CMDB_CIID   >> ${CMDB_CIID}" | tee -a ${CMDB_LOG}
				CMDB_NAME=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $2 }' | sed -e 's/+^+/ /g'`
				debug "CMDB_NAME   >> ${CMDB_NAME}" | tee -a ${CMDB_LOG}
				COST_CENTER=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $3 }' | sed -e 's/+^+/ /g'`
				debug "COST_CENTER >> ${COST_CENTER}" | tee -a ${CMDB_LOG}
				DESCRIPTION=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $6 }' | sed -e 's/+^+/ /g'`
				debug "DESCRIPTION >> ${DESCRIPTION}" | tee -a ${CMDB_LOG}
				NAME=`echo "${NEWCI}" | sed -e 's/\",\"/  /g' | sed 's/\"//g' | awk '{ print $4}' | sed -e 's/+^+/ /g'`
				debug "NAME        >> ${NAME}" | tee -a ${CMDB_LOG}
	
				echo "${COUNT} - Creating NEW Property Instance \"${NAME}\"" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance createInstance Class://SystemObject/CMDB_Application ${NAME} "${DESCRIPTION}"  #>/dev/null 2>/dev/null
				if ! test $? -eq 0; then
						echo "ERROR: Create Instance Failed - Class://SystemObject/CMDB_Application/${NAME}" | tee -a ${CMDB_LOG}
					else
						echo "\tClass://SystemObject/CMDB_Application/${NAME} was created." | tee -a ${CMDB_LOG}
				fi
				echo "\tSetting permissions to Everyone PropertyInstance.Read for \"${NAME}\"" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance addPermissionsToPropertyInstanceSet Class://SystemObject/CMDB_Application/${NAME} Everyone PropertyInstance.Read >/dev/null 2>/dev/null
				if ! test $? -eq 0; then
						echo "ERROR: Failed to set Permissions of \"Everyone PropertyInstance.Read\" to property instance ${NAME}." | tee -a ${CMDB_LOG}
					else
						echo "\tPermissions of \"Everyone PropertyInstance.Read\" to property instance ${NAME} were set." | tee -a ${CMDB_LOG}
				fi
				echo "\tSetting permissions to WindowsAdmins PropertyInstance.Modify for \"${NAME}\"" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance addPermissionsToPropertyInstanceSet Class://SystemObject/CMDB_Application/${NAME} WindowsAdmins PropertyInstance.Modify >/dev/null 2>/dev/null
				if ! test $? -eq 0; then
						echo "ERROR: Failed to set Permissions of \"WindowsAdmins PropertyInstance.Modify\" to property instance ${NAME}." | tee -a ${CMDB_LOG}
					else
						echo "\tPermissions of \"WindowsAdmins PropertyInstance.Modify\" to property instance ${NAME} were set." | tee -a ${CMDB_LOG}
				fi
				echo "\tSetting permissions to UnixAdmins PropertyInstance.Modify for \"${NAME}\"" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance addPermissionsToPropertyInstanceSet Class://SystemObject/CMDB_Application/${NAME} UnixAdmins PropertyInstance.Modify >/dev/null 2>/dev/null
				if ! test $? -eq 0; then
						echo "ERROR: Failed to set Permissions of \"UnixAdmins PropertyInstance.Modify\" to property instance ${NAME}." | tee -a ${CMDB_LOG}
					else
						echo "\tPermissions of \"UnixAdmins PropertyInstance.Modify\" to property instance ${NAME} were set." | tee -a ${CMDB_LOG}
				fi
				echo "\tSetting permissions to DCE PropertyInstance.Modify for \"${NAME}\"" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance addPermissionsToPropertyInstanceSet Class://SystemObject/CMDB_Application/${NAME} DCE PropertyInstance.Modify >/dev/null 2>/dev/null
				if ! test $? -eq 0; then
						echo "ERROR: Failed to set Permissions of \"DCE PropertyInstance.Modify\" to property instance ${NAME}." | tee -a ${CMDB_LOG}
					else
						echo "\tPermissions of \"DCE PropertyInstance.Modify\" to property instance ${NAME} were set." | tee -a ${CMDB_LOG}
				fi
				echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"APP_OWNER\",\"${APP_OWNER}\"" >> ${BL_CMDB_UPDATE}
				echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"CMDB_CIID\",\"${CMDB_CIID}\"" >> ${BL_CMDB_UPDATE}
				echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"CMDB_Name\",\"${CMDB_NAME}\"" >> ${BL_CMDB_UPDATE}
				echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"Cost_Center\",\"${COST_CENTER}\"" >> ${BL_CMDB_UPDATE}
				echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"SSA_Name\",\"${CMDB_NAME}\"" >> ${BL_CMDB_UPDATE}
				COUNT=`expr ${COUNT} - 1`
			done
		else
			echo "There were no CMDB_Application to be added to TrueSight." | tee -a ${CMDB_LOG}
	fi
}

debug()
	{
		if [ $DEBUG = "1" ]; then
			printf "$1\n" 
		fi
	}

DeleteCmdbInstance ()
	{
	#######
	## INFO - 
	#######
	log_header_output DeleteCmdbInstance | tee -a ${CMDB_LOG}
	EXIT_CODE=0
	if test -f ${BL_CMDB_DELETE_APP}; then
			COUNT=`wc ${BL_CMDB_DELETE_APP} | awk '{ print $1 }'`
			APPS=`cat ${BL_CMDB_DELETE_APP}`
			while IFS= read -r LINE
				do
				echo "${COUNT} - Deleting Instance \"${LINE}\" true" | tee -a ${CMDB_LOG}
				blcli_execute PropertyInstance deleteInstance ${LINE} true >/dev/null 2>/dev/null
				if ! test $? = 0; then
						echo "INFO - \"${LINE}\" was not deleted." | tee -a ${CMDB_LOG}
						EXIT_CODE=3
					else
						LINE_NAME=`echo "${LINE}" | sed 's/Class:\/\/SystemObject\/CMDB_Application\///g'`
						echo "\tINFO: LINE >> ${LINE}"
						echo "\tINFO: LINE_NAME >> ${LINE_NAME}"
#						debug "EXECUTING: UpdateAppInstanceName ${LINE} setDescription \"${LINE_NAME}_[DEPRECATED]\""
						UpdateAppInstanceName ${LINE} setDescription "${LINE_NAME}_[DEPRECATED]"
#						debug "EXECUTING: UpdateAppInstanceName ${LINE} setName \"${LINE_NAME}_[DEPRECATED]\""
						UpdateAppInstanceName ${LINE} setName "${LINE_NAME}_[DEPRECATED]"
				fi
				COUNT=`expr ${COUNT} - 1`
				done < "${BL_CMDB_DELETE_APP}"
		else
			echo "There were no CMDB_Application properties to delete." | tee -a ${CMDB_LOG}
	fi
	}

FileCleanup ()
	{
	FILECLEAN=$1
	if test -f ${FILECLEAN}; then
		debug "Deleting: ${FILECLEAN}" | tee -a ${CMDB_LOG}
		rm ${FILECLEAN}
	fi
	}

FindNewDeprecatedCiid ()
	{
	log_header_output FindNewDeprecatedCiid | tee -a ${CMDB_LOG}
	#######
	## INFO - Check the remaining CMDB Applications from the "BL_CMDB_APP_LIST" to see if any new Application CI's have been depricated.
	## INFO - Add any new depricated application CI's to the "BL_CMDB_DEPRECATED" list.
	#######
	FileCleanup ${TEMP_FILE_1}
	FileCleanup ${TEMP_FILE_2}
	APP_LIST=`cat ${BL_CMDB_APP_LIST}`
	COUNT=`wc ${BL_CMDB_APP_LIST} | awk '{ print $1}'`
#	debug "${APP_LIST}"
#	debug "COUNT >> ${COUNT}"
	for LINE in ${APP_LIST}
		do
#			debug "EXECUTING: blcli_execute PropertyInstance isInstanceDeprecated ${LINE}"
			blcli_execute PropertyInstance isInstanceDeprecated ${LINE} >/dev/null 2>/dev/null
			blcli_storeenv RESULTS
			if [ "${RESULTS}" = "true" ]; then
#					echo "++++++++++++++++++++++++++++++++++"
#					debug "RESULTS >> ${RESULTS}" | tee -a ${CMDB_LOG}
					echo "${COUNT} - DEPRECATED: \"${LINE}\" - Adding to deprecated list." | tee -a ${CMDB_LOG}
					echo "\tINFO: ${LINE}" | tee -a ${CMDB_LOG}
					echo "\tINFO: ${LINE}_[DEPRECATED]" | tee -a ${CMDB_LOG}
#					debug "${LINE}" | sed 's/Class:\/\/SystemObject\/CMDB_Application\///g'
#					debug "EXECUTING: LINE_NAME=\`echo \"${LINE}\" | sed 's/Class:\/\/SystemObject\/CMDB_Application\///g'\`"
					LINE_NAME=`echo "${LINE}" | sed 's/Class:\/\/SystemObject\/CMDB_Application\///g'`
#					echo "\tINFO: LINE_NAME >> ${LINE_NAME}"
#					debug "EXECUTING: UpdateAppInstanceName ${LINE} setDescription \"${LINE_NAME}_[DEPRECATED]\""
					UpdateAppInstanceName ${LINE} setDescription "${LINE_NAME}_[DEPRECATED]"
#					debug "EXECUTING: UpdateAppInstanceName ${LINE} setName \"${LINE_NAME}_[DEPRECATED]\""
					UpdateAppInstanceName ${LINE} setName "${LINE_NAME}_[DEPRECATED]"
#					echo "++++++++++++++++++++++++++++++++++"
				else
#					debug "RESULTS >> ${RESULTS}" | tee -a ${CMDB_LOG}
					echo "${COUNT} - Valid \"${LINE}\"" | tee -a ${CMDB_LOG}
			fi
			COUNT=`expr ${COUNT} - 1`
		done
#	if test -f ${TEMP_FILE_1}; then
#			echo "INFO: Updating //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv" | tee -a ${CMDB_LOG}
#			cp -v //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv ${BL_CMDB_DEPRECATED} | tee -a ${CMDB_LOG}
#			cat ${TEMP_FILE_1} >> ${BL_CMDB_DEPRECATED}
#			cat ${BL_CMDB_DEPRECATED} | sort | uniq > //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv
#		else
#			echo "INFO: No new deprecated entries were found." | tee -a ${CMDB_LOG}
#	fi
	# FileCleanup ${TEMP_FILE_1}
	}

FindEntryNoLongerInCMDB ()
	{
	#######
	## INFO - Compare BladeLogic Application CI's against CMDB dump.  This process will identify CIID's that have been updated.
	#######
	log_header_output FindEntryNoLongerInCMDB | tee -a ${CMDB_LOG}
#	cp -v ${BL_CMDB_APPS} ${BL_CMDB_APPS}.${TIME_STAMP}
	FileCleanup ${BL_CMDB_DELETE_APP}
	FileCleanup ${BL_CMDB_UPDATE}
	FileCleanup ${TEMP_FILE_1}
	FileCleanup ${TEMP_FILE_2}
	touch ${TEMP_FILE_2}
	COUNT=`wc ${BL_CMDB_APPS} | awk '{ print $1 }'`
	APPS=`cat ${BL_CMDB_APPS} | sed 's/\",\"/    /g' | sed 's/\"//g' | awk '{ print $1 }'`
	for APP in $APPS
		do
			if ! test ${APP}; then
					APP=UNKNOW_CIID
				else
					DESCRIPTION=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $6 }'`
#					echo "EXECUTING: cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/\"//g' | awk '{ print $5 }'"
					NAME=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $5 }'`
					CMDB_NAME=`cat ${BL_CMDB_APPS} | grep ${APP} | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $2 }' | sed 's/_/ /g'`
					if grep -q -i ${APP} ${CMDB_FILE}; then
							echo "${COUNT} - CMDB_Application CIID \"${APP}\" exists." | tee -a ${CMDB_LOG}
							grep ${APP} ${BL_CMDB_APPS} >> ${TEMP_FILE_1}
						else
							echo "${COUNT} - CMDB_Application CIID \"${APP}\" was NOT found in the CMDB dump.\n\tINFO: Checking for Property Instance Name: \"${NAME}\"." | tee -a ${CMDB_LOG}
#							echo "EXECUTING: cat ${CMDB_FILE} | grep -q ",\"${NAME}\"""
							if cat ${CMDB_FILE} | grep -q ",\"${NAME}\"" ; then
#							if grep -q ",\"${NAME}\"" ${CMDB_FILE}; then
									NEW_CMDB_CIID=`cat ${CMDB_FILE} | grep "\"${NAME}\"" | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print $1 }'`
									echo "\tINFO: ${NAME} was found in ${CMDB_FILE}.\n\tINFO: CIID will need to updateded to \"${NEW_CMDB_CIID}\"." | tee -a ${CMDB_LOG}
									echo "\t\tOld CMDB_CIID >> ${APP}" >> ${CMDB_LOG}
									echo "\t\tNew CMDB_CIID >> ${NEW_CMDB_CIID}" >> ${CMDB_LOG}
									## Write the change that needs to be done to "BL_CMDB_update.csv" 
									echo "\"Class://SystemObject/CMDB_Application/${NAME}\",\"CMDB_CIID\",\"${NEW_CMDB_CIID}\"" >> ${BL_CMDB_UPDATE}
		
									## Add the updated CIID to "BL_CMDB_Apps.csv" for future processing.
									OUTPUT=`grep ${APP} ${BL_CMDB_APPS} | sed 's/_/^^^/g' | sed 's/ /_/g' | sed 's/,/~,~/g' | sed 's/\"~,~\"/   /g' | sed 's/"//g' | awk '{ print "\",\""$2"\",\""$3"\",\""$4"\",\""$5"\",\""$6"\"" }'  | sed 's/_/ /g' | sed 's/\^\^\^/_/g'`
									echo "NEW_CMDB_CIID >> ${NEW_CMDB_CIID}" >> ${CMDB_LOG}
									echo "OUTPUT >> ${OUTPUT}" >> ${CMDB_LOG}
									echo "\t\"${NEW_CMDB_CIID}${OUTPUT}" >> ${CMDB_LOG}
									echo "\"${NEW_CMDB_CIID}${OUTPUT}" >> ${TEMP_FILE_2}
									
	#								## Remove the CIID from the "BL_CMDB_Apps.csv" so the data can be updated.
	#								grep -v "${NAME}" ${BL_CMDB_APPS} > ${TEMP_FILE_1}; cat ${TEMP_FILE_1} | sort | uniq > ${BL_CMDB_APPS}
	#								echo "Verify"
	#								grep "${NAME}" ${BL_CMDB_APPS}
	#								grep "${APP}" ${BL_CMDB_APPS}
	#								cat ${BL_CMDB_APPS} | grep ${APP}
								else
									echo "\tApplication \"${NAME}\" was NOT found in the CMDB dump,\n\tINFO: CMDB intance will be DEPRECATED." | tee -a ${CMDB_LOG}
									debug "\t\tAPP >> \"${APP}\"" >> ${CMDB_LOG}
									debug "\t\tDESCRIPTION >> \"${DESCRIPTION}\"" >> ${CMDB_LOG}
									debug "\t\tCMDB_NAME >> \"${CMDB_NAME}\"" >> ${CMDB_LOG}
									debug "\t\tNAME >> \"${NAME}\"" >> ${CMDB_LOG}
	#								UpdateAppInstanceName Class://SystemObject/CMDB_Application/${BL_APP_NAME} setName "${NAME}"
									echo "Class://SystemObject/CMDB_Application/${NAME}" >> ${BL_CMDB_DELETE_APP}
	#								echo "Class://SystemObject/CMDB_Application/${NAME}" >> ${BL_CMDB_DEPRECATED}
							fi
					fi
					COUNT=`expr ${COUNT} - 1`
			fi
		done
	mv  ${TEMP_FILE_1} ${BL_CMDB_APPS}
	cat ${TEMP_FILE_2} >> ${BL_CMDB_APPS}
#	cat ${BL_CMDB_DEPRECATED} | sort | uniq > //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv
#	cp -v ${BL_CMDB_DEPRECATED} //blfs/${${WORK_PATH}}/BL_CMDB_Deprecated.csv >> ${CMDB_LOG}
	# FileCleanup ${TEMP_FILE_1}
	# FileCleanup ${TEMP_FILE_2}
	}

log_header_output ()
	{
	NAME_RUN=$1
	echo "\n________________________"
	echo "Executing: \"${NAME_RUN}\"\n"
	}

UpdateAppInstanceName ()
	{
	#######
	## INFO - 
	#######
	log_header_output UpdateAppInstanceName >> ${CMDB_LOG}
	CLASS_NAME=$1
	INSTANCE_TYPE=$2			#setName or setDescription
	INSTANCE_NAME=$3
	blcli_execute PropertySetInstance findPropertySetInstanceByFullyQualifiedName "${CLASS_NAME}" >/dev/null 2>/dev/null
		if test $? = 0; then
				blcli_execute Utility storeTargetObject psi >/dev/null 2>/dev/null
				blcli_execute PropertySetInstance ${INSTANCE_TYPE} "${INSTANCE_NAME}" >/dev/null 2>/dev/null
				blcli_execute PropertySetInstance update NAMED_OBJECT=psi >/dev/null 2>/dev/null
				if test $? = 0; then
						echo "${INSTANCE_TYPE} of \"${CLASS_NAME}\" has been changed to \"${INSTANCE_NAME}\" in the BladeLogic CMDB_Application Custom Property Class." | tee -a ${CMDB_LOG}
					else
						echo "\nNo changes were made to correct \"${CLASS_NAME}\" in the BladeLogic CMDB_Application Custom Property Class.\n" | tee -a ${CMDB_LOG}
						EXIT_CODE=1
				fi
			else
				echo "There was no record of \"${CLASS_NAME}\" in the Database" | tee -a ${CMDB_LOG}
		fi
	}
########################################################################
## Run Execution of Script


#CmdbDataPrep					## Files Used: ${CMDB_FILE}, ${CMDB_DUMP}, ${TEMP_FILE_1}
#BlPullCmdbLists				## (EXIT=1) Files Used: ${BL_CMDB_APP_LIST}, ${TEMP_FILE_1}
		#	BlRemoveDeprecated				## Files Used: ${BL_CMDB_APP_LIST}, ${BL_CMDB_DEPRECATED}, ${TEMP_FILE_1}
		#	FindNewDeprecatedCiid			## Files Used: ${BL_CMDB_APP_LIST}, ${BL_CMDB_DEPRECATED}, ${TEMP_FILE_1}, ${TEMP_FILE_2}
#BlPullCmdbAppData				## (EXIT=2) Files Used: ${BL_CMDB_APP_LIST}, ${BL_CMDB_APPS}, ${TEMP_FILE_1}
		#	CheckForDuplicateCiid		## Files Used: ${BL_CMDB_APPS}
#FindEntryNoLongerInCMDB			## Files Used: ${BL_CMDB_APPS}, ${BL_CMDB_DELETE_APP}, ${BL_CMDB_DEPRECATED}, ${BL_CMDB_UPDATE}, ${CMDB_FILE}, ${TEMP_FILE_1}, ${TEMP_FILE_2}
DeleteCmdbInstance				## (EXIT=3) Files Used: ${BL_CMDB_DELETE_APP}
CheckAppData					## Files Used: ${BL_CMDB_APPS}, ${CMDB_FILE}, ${BL_CMDB_NEW}
CreatNewCmdbInstance			## Files Used: ${BL_CMDB_UPDATE}, ${BL_CMDB_NEW}
ApplyUpdates					## Files Used: ${BL_CMDB_UPDATE}

mv ${TARGET}/${WORK_PATH}/*.log //blfs/storage/bladmintmp/CMDB/logs

log_header_output EXIT | tee -a ${CMDB_LOG}
echo "\nEXIT_CODE = ${EXIT_CODE}\n"

exit ${EXIT_CODE}
	
