#!/bin/nsh
#
#######################################################################
#<doc>	NAME
#<doc>		CMDBServerSync.nsh
#<doc>	DESCRIPTION:
#<doc>		Sync CBS base card files
#<doc>	SCRIPT TYPE:
#<doc>		NSH Script 
#<doc>			#2 - Execute the script one, passing the host list as a parameter to the script.
#<doc>			Allow run with no targets - is checked.
#<doc>	SYNTAX:
#<doc>		CMDBServerSync.nsh [TARGET]
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

TARGET=$1
BLSERVER=//@																		## Denotes local BL APP Server where script is ran.
WORK_PATH="storage/bladmintmp"												## The default working path.
TIME_STAMP=`date '+%Y%m%d_%H%M'`												## date '+%m-%d-%Y %H:%M:%S'
SMARTGROUP_LIST=/Applications
DEBUG=1																	# "1"	## Debug 1=ON 0=OFF
EXIT_CODE=0																# "0"	## Default EXIT_CODE=0

CMDB_APPS="${BLSERVER}/${WORK_PATH}/BL_CMDB_Apps.csv"							## The output of the BladeLogic CMDB_Applications data.
BL_SERVER_GROUPS="${BLSERVER}/${WORK_PATH}/BL_Server_Groups.csv"
BL_SERVER_UPDATES="${BLSERVER}/${WORK_PATH}/BL_Server_Update.csv"							## The output of the BladeLogic CMDB_Applications data.
SMARTGROUPS="${BLSERVER}/${WORK_PATH}/Server_Smartgroups.csv"
TEMP_FILE_1="${BLSERVER}/${WORK_PATH}/temp1.csv"
LOG_FILE="${BLSERVER}/${WORK_PATH}/CMDBServerSync_${TIME_STAMP}.log"

#	END Init variables
########################################################################

CreateServerSmartGroup ()
	{
	APP=$1
	CLEAN_APP=$2
	CMDB_NAME=`echo ${APP} | tr '[:lower:]' '[:upper:]'`
	#echo "_______________________________"
	#echo "\tCLEAN_APP >> ${CLEAN_APP}"
	#echo "\tAPP >> ${APP}"
#	echo "\n\tCMDB_NAME >> ${CMDB_NAME}"
#	cat //utlxa201/storage/bladmintmp/CMDB/BL_CMDB_Apps.csv | grep "\"${CMDB_NAME}\""
	
	blcli_execute SmartServerGroup createGroup "/Applications" "${CLEAN_APP}" "${CLEAN_APP}" "CMDB_APPLICATION" "equals" "Class://SystemObject/CMDB_Application/${CMDB_NAME}" >/dev/null 2>/dev/null
#	if test $? -eq 0; then
#	echo "Exit Code >> $?"
	blcli_execute Group addPermission 5007 "/Applications/${CLEAN_APP}" Everyone ServerGroup.Read >/dev/null 2>/dev/null
#	echo "Exit Code >> $?"
#		else
#			blcli_execute SmartServerGroup deleteGroupByQualifiedName "/Applications/${NEW_NAME}" >/dev/null 2>/dev/null
#			blcli_execute SmartServerGroup deleteGroupByQualifiedName "/Applications/${CMDB_NAME}" >/dev/null 2>/dev/null
#			blcli_execute SmartServerGroup createGroup "/Applications" "${NEW_NAME}" "${NEW_NAME} - Cost Center: ${COST}" "CMDB_APPLICATION" "equals" "Class://SystemObject/CMDB_Application/${CMDB_NAME}" >/dev/null 2>/dev/null
#			if test $? -eq 0; then
#					blcli_execute Group addPermission 5007 "/Applications/${NEW_NAME}" Everyone ServerGroup.Read >/dev/null 2>/dev/null											
#				else
#		echo "ERROR: Unable to create New Server Smart Group for \"${NEW_NAME} - Cost Center: ${COST}\"." | tee -a ${ERROR_LOG}
#	fi
#	fi
	}

DeleteServerSmartGroup ()
	{
	SMARTGROUP=$1
	blcli_execute SmartServerGroup deleteGroupByQualifiedName "/Applications/${SMARTGROUP}" >/dev/null 2>/dev/null
	if test $? -eq 0; then
#			echo "INFO: /Applications/${SMARTGROUP} has been deleted."
		else
			echo "ERROR: There were problems deleting /Applications/${SMARTGROUP}."
	fi
	}

FileCleanup ()
	{
	FILECLEAN=$1
	if test -f ${FILECLEAN}; then
		echo "Deleting: ${FILECLEAN}" | tee -a ${LOG_FILE}
		rm ${FILECLEAN}
	fi
	}

GetServerAppName ()
	{
	log_header_output GetServerAppName | tee -a ${LOG_FILE}
	blcli_execute Server printPropertyValue "${TARGET}" CMDB_APPLICATION >/dev/null 2>/dev/null
	blcli_storeenv CMDB_APP_DBKEY
	blcli_execute PropertyInstance getPropertyInstanceNameByDBKey "${CMDB_APP_DBKEY}" >/dev/null 2>/dev/null
	blcli_storeenv CMDB_APP_NAME
	echo "CMDB_APP_NAME >> ${CMDB_APP_NAME}" | tee -a ${LOG_FILE}

	}
	
RemoveOldBLSmartgroups ()
	{
	log_header_output RemoveOldBLSmartgroups | tee -a ${LOG_FILE}
	#SERVER_GROUPS=`cat ${BL_SERVER_GROUPS}`
	C_COUNT=`echo "${BL_SERVER_GROUPS}" | wc | awk '{ print $1 }'`
	COUNT=${C_COUNT}
	for APP in ${BL_SERVER_GROUPS}
		do
			RESULTS=`echo ${CMDB_APP_LIST} | grep "${APP}"`
			if [ -z ${RESULTS} ]; then
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
			#		DeleteServerSmartGroup "${CLEAN_APP}"
					echo "${C_COUNT} of ${COUNT} - DELETING ${CLEAN_APP} Server Smartgroup."
				else
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP}"
			fi
			C_COUNT=`expr ${C_COUNT} - 1`
		done
	}

AddNewSmartgroups ()
	{
	log_header_output AddNewSmartgroups | tee -a ${LOG_FILE}
	#APP_NAMES=`cat ${CMDB_APPS}`
	C_COUNT=`echo "${CMDB_APP_LIST}" | wc | awk '{ print $1 }'`
	COUNT=${C_COUNT}
	echo "${CMDB_APP_LIST}"
	for APP in ${CMDB_APP_LIST}
		do
			echo "____________________________"
			echo "${APP}"
			cat ${BL_SERVER_GROUPS} | grep "${APP}"
	exit 0
			RESULTS=`echo ${BL_SERVER_GROUPS} | grep "${APP}"`
			echo "RESULTS >> ${RESULTS}"
			if [ -z ${RESULTS} ]; then
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - NEW Server Smartgroup \"${CLEAN_APP}\" will be created."
					#echo "\tAPP >> DeleteServerSmartGroup \"${APP}\""
					#echo "\tCLEAN_APP >> DeleteServerSmartGroup \"${CLEAN_APP}\""
				#	CreateServerSmartGroup "${APP}" "${CLEAN_APP}"
				else
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP} Exists"
			fi
			C_COUNT=`expr ${C_COUNT} - 1`
		done
	}

log_header_output ()
	{
	NAME_RUN=$1
	echo "\n________________________"
	echo "Executing: \"${NAME_RUN}\"\n"
	}

UpdateServerProperties ()
	{
	log_header_output UpdateServerProperties | tee -a ${LOG_FILE}
	FileCleanup ${BL_SERVER_UPDATES}
	G_COUNT=`cat "${SMARTGROUPS}" | wc | awk '{ print $1}'`
	TG_COUNT=`cat "${SMARTGROUPS}" | wc | awk '{ print $1}'`
		while IFS= read -r CMDB_APPLICATION_NAME
			do
				CMDB_INFO=`cat ${CMDB_APPS} | grep "\"${CMDB_APPLICATION_NAME}\""`
				#echo "___________________________"
				#echo "\tCMDB_INFO >> ${CMDB_INFO}"
				#echo "___________________________"
				if [ -z ${CMDB_INFO} ]; then
						echo "${G_COUNT} of ${TG_COUNT} - ${CMDB_APPLICATION_NAME}" | tee -a ${LOG_FILE}
						echo "ERROR: Data NOT Found!!!" | tee -a ${LOG_FILE}
						EXIT_CODE=1
					else
						echo "${G_COUNT} of ${TG_COUNT} - ${CMDB_APPLICATION_NAME}" | tee -a ${LOG_FILE}
						GroupName="/Applications/${CMDB_APPLICATION_NAME}"
						SERVER_LIST=`blcli Server listServersInGroup "${GroupName}"`
						if [ -z ${SERVER_LIST} ]; then
								echo "\tINFO: No servers found in \"/Applications/${CMDB_APPLICATION_NAME}\"." | tee -a ${LOG_FILE}
							else
								COST_CENTER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $3 }'`
								CUSTOMER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $4 }' | sed 's/_/ /g'`
								echo "\t\tCMDB_APPLICATION_NAME >> ${CMDB_APPLICATION_NAME}" | tee -a ${LOG_FILE}
								echo "\t\tCOST_CENTER >> ${COST_CENTER}" | tee -a ${LOG_FILE}
								echo "\t\tCUSTOMER >> ${CUSTOMER}" | tee -a ${LOG_FILE}
								S_COUNT=`echo "${SERVER_LIST}" | wc | awk '{ print $1}'`
								TS_COUNT=`echo "${SERVER_LIST}" | wc | awk '{ print $1}'`
								for LINE in ${SERVER_LIST}
									do
										echo "\tServer ${S_COUNT} of ${TS_COUNT} - ${LINE}" | tee -a ${LOG_FILE}
										echo "\"${LINE}\",\"CMDB_APPLICATION_NAME\",\"${CMDB_APPLICATION_NAME}\"" >> ${BL_SERVER_UPDATES}
										echo "\"${LINE}\",\"COST_CENTER\",\"${COST_CENTER}\"" >> ${BL_SERVER_UPDATES}
										echo "\"${LINE}\",\"CUSTOMER\",\"${CUSTOMER}\"" >> ${BL_SERVER_UPDATES}
										S_COUNT=`expr ${S_COUNT} - 1`
									done
						fi
				fi
				G_COUNT=`expr ${G_COUNT} - 1`
			done < "${SMARTGROUPS}"
	blcli Server bulkSetServerPropertyValues "/${WORK_PATH}" "BL_Server_Update.csv"
	}	


GetDataLists ()
	{
	log_header_output GetDataLists | tee -a ${LOG_FILE}
#	FileCleanup ${BL_SERVER_GROUPS}
#	FileCleanup ${TEMP_FILE_1}
	
	cp -v //utlxa202/storage/bladmintmp/CMDB/CMDB_master.csv ${BLSERVER}/${WORK_PATH}/CMDB_master.csv | tee -a ${LOG_FILE}
	ls -lart //utlxa202/storage/bladmintmp/CMDB/CMDB_master.csv
	ls -lart ${BLSERVER}/${WORK_PATH}/CMDB_master.csv
	CMDB_APP_LIST=`cat ${BLSERVER}/${WORK_PATH}/CMDB_master.csv | sed 's/\[/++-/g' | sed 's/\]/+++/g' | sed 's/\:/ -/g' | sed 's/_/+-+/g' | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $2 }' | sort`
#	echo "${CMDB_APP_LIST}"

	blcli_execute ServerGroup listChildGroupsInGroup "${SMARTGROUP_LIST}"  > ${TEMP_FILE_1}  >/dev/null 2>/dev/null
	#blcli_storeenv TEMP_LIST
	cat "${TEMP_FILE_1}" | grep -v "DEPRECATED CMDB_APPLICATION CIID's" | sed 's/\[/++-/g' | sed 's/\]/+++/g' | sed 's/\:/ -/g' | sed 's/_/+-+/g' | sed 's/ /_/g' | sort > ${BL_SERVER_GROUPS}
	#BL_SERVER_GROUPS=`cat "${BL_SERVER_GROUPS}"`
	#	echo "${BL_SERVER_GROUPS}"

	}
RemoveOldBLSmartgroups ()
	{
	log_header_output RemoveOldBLSmartgroups | tee -a ${LOG_FILE}
	SERVER_GROUPS=`cat ${BL_SERVER_GROUPS}`
	C_COUNT=`echo "${BL_SERVER_GROUPS}" | wc | awk '{ print $1 }'`
	COUNT=${C_COUNT}
	for APP in ${BL_SERVER_GROUPS}
		do
			echo "APP >> ${APP}"
			RESULTS=`echo ${CMDB_APP_LIST} | grep "${APP}"`
			echo "RESULTS >> ${RESULTS}"
			exit 0
			if [ -z ${RESULTS} ]; then
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
			#		DeleteServerSmartGroup "${CLEAN_APP}"
					echo "${C_COUNT} of ${COUNT} - DELETING ${CLEAN_APP} Server Smartgroup."
				else
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP}"
			fi
			C_COUNT=`expr ${C_COUNT} - 1`
		done
	}

########################################################################

GetDataLists

RemoveOldBLSmartgroups
#AddNewSmartgroups
#CheckMissingSmartgroups
#UpdateServerProperties

##echo
#| sed 's/_/ /g' | sed 's/+-+/_/g'
#rm ${SMARTGROUPS}
#rm ${TEMP_FILE_1}
# >> ${TEMP_FILE_1}
#cat ${TEMP_FILE_1} | grep -v "DEPRECATED CMDB_APPLICATION CIID's" > ${SMARTGROUPS}
#rm ${TEMP_FILE_1}
#echo
#GroupName="/Applications/BaNCS (ODS)"
#blcli ServerGroup groupNameToDBKey "/Applications"
#exit 0
#echo "\n\nEXECUTING: blcli SmartServerGroup groupNameToDBKey \"$GroupName\""
#GROUP_DBKEY=`blcli SmartServerGroup groupNameToDBKey "$GroupName"`
#blcli_storeenv GROUP_DBKEY
#echo "\n\nEXECUTING: blcli Server bulkSetServerPropertyInGroup ${GROUP_DBKEY} CMDB_APPLICATION_NAME \"BaNCS (ODS)\" true"
#blcli Server bulkSetServerPropertyInGroup ${GROUP_DBKEY} CMDB_APPLICATION_NAME "BaNCS (ODS)" true
#echo
#blcli_execute Group groupNameToId "$GroupName" 5007
#blcli Group groupNameToDBKey "${GroupName}" 5007
#echo
#GetServerAppName

#	CMDB_INFO=`cat ${CMDB_APPS} | grep ${CMDB_APP_NAME}`
#	CMDB_APPLICATION_NAME=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $2 }' | sed 's/_/ /g'`
#	COST_CENTER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $3 }'`
#	CUSTOMER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $4 }' | sed 's/_/ /g'`
#	echo "CMDB_APPLICATION_NAME >> ${CMDB_APPLICATION_NAME}" | tee -a ${LOG_FILE}
#	echo "COST_CENTER >> ${COST_CENTER}" | tee -a ${LOG_FILE}
#	echo "CUSTOMER >> ${CUSTOMER}" | tee -a ${LOG_FILE}


