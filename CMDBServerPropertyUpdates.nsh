#!/bin/nsh
#
#######################################################################
#<doc>	NAME
#<doc>		CMDBServerPropertyUpdates.nsh
#<doc>	DESCRIPTION:
#<doc>		Sync CBS base card files
#<doc>	SCRIPT TYPE:
#<doc>		NSH Script 
#<doc>			#2 - Execute the script one, passing the host list as a parameter to the script.
#<doc>			Allow run with no targets - is checked.
#<doc>	SYNTAX:
#<doc>		./CMDBServerPropertyUpdates.nsh
#<doc>	DIAGNOSTICS:
#<doc>		Exit code 0 if successful
#<doc>		Exit code 1 on failure
#<doc>		Exit code 2 on failure in process but not in full script.
#<doc>	OWNER:
#<doc>		Copyright (C) 2018 ZB, N.A.
########################################################################
#	DATE		MODIFIED BY		REASON FOR & DESCRIPTION OF MODIFICATION
#	--------	-------------	----------------------------------------
#	12/12/2018	Frank Brand	Written
########################################################################
#	Init variables

BLSERVER=//@																	## Denotes local BL APP Server where script is ran.
WORK_PATH="storage/bladmintmp/properties"										## The default working path.
TIME_STAMP=`date '+%Y%m%d_%H%M'`												## date '+%m-%d-%Y %H:%M:%S'
SMARTGROUP_LIST=/Applications
DEBUG=1																	# "1"	## Debug 1=ON 0=OFF
EXIT_CODE=0																# "0"	## Default EXIT_CODE=0

CMDB_APPS="${BLSERVER}/${WORK_PATH}/CMDB_Apps.txt"								## The output of the BladeLogic CMDB_Applications data.
CMDB_MASTER="${BLSERVER}/${WORK_PATH}/CMDB_master.txt"
BL_SERVER_GROUPS="${BLSERVER}/${WORK_PATH}/BL_Server_Groups.txt"
BL_SERVER_UPDATES="${BLSERVER}/${WORK_PATH}/BL_Server_Update.txt"
SMARTGROUPS="${BLSERVER}/${WORK_PATH}/Server_Smartgroups.txt"
TEMP_FILE_1="${BLSERVER}/${WORK_PATH}/temp1.txt"
LOG_FILE="${BLSERVER}/${WORK_PATH}/logs/CMDBServerPropertyUpdates_${TIME_STAMP}.log"

#	END Init variables
########################################################################
#	Functions


AddNewSmartgroups ()
	{
	log_header_output AddNewSmartgroups | tee -a ${LOG_FILE}
	APP_NAMES=`cat ${CMDB_APPS}`
	C_COUNT=`echo "${APP_NAMES}" | wc | awk '{ print $1 }'`
	COUNT=${C_COUNT}
	for APP in ${APP_NAMES}
		do
			RESULTS=`cat ${BL_SERVER_GROUPS} | grep "${APP}"`
		#	echo "RESULTS >> ${RESULTS}"
			if [ -z ${RESULTS} ]; then
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ***NEW*** Server Smartgroup \"${CLEAN_APP}\" will be created." | tee -a ${LOG_FILE}
					CreateServerSmartGroup "${APP}" "${CLEAN_APP}"
				else
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP} \"Exists\"" | tee -a ${LOG_FILE}
			fi
			C_COUNT=`expr ${C_COUNT} - 1`
		done
	}

CreateServerSmartGroup ()
	{
	APP=$1
	echo "APP >> ${APP}"

	CLEAN_APP=$2
	echo "CLEAN_APP >> ${CLEAN_APP}"

	CMDB_NAME=`echo ${APP} | tr '[:lower:]' '[:upper:]' | sed 's/+-+/_/g'`
	echo "CMDB_NAME >> ${CMDB_NAME}"

	echo "blcli_execute SmartServerGroup createGroup \"/Applications\" \"${CLEAN_APP}\" \"${CLEAN_APP}\" \"CMDB_APPLICATION\" \"equals\" \"Class://SystemObject/CMDB_Application/${CMDB_NAME}\""
	blcli_execute SmartServerGroup createGroup "/Applications" "${CLEAN_APP}" "${CLEAN_APP}" "CMDB_APPLICATION" "equals" "Class://SystemObject/CMDB_Application/${CMDB_NAME}" #>/dev/null 2>/dev/null
	exit 0
	if test $? -eq 0; then
			blcli_execute Group addPermission 5007 "/Applications/${CLEAN_APP}" Everyone ServerGroup.Read #>/dev/null 2>/dev/null
			if test $? -eq 0; then
					echo "Permissions of \"Everyone ServerGroup.Read\" has been applied to \"/Applications/${CLEAN_APP}\"" | tee -a ${LOG_FILE}
				else
					echo "ERROR: Failed to apply Permissions of \"Everyone ServerGroup.Read\" to \"/Applications/${CLEAN_APP}\"" | tee -a ${LOG_FILE}
					EXIT_CODE=3
			fi
		else
			echo "\t\tERROR: Failed to create new Server Smartgroup for \"/Applications/${CLEAN_APP}\"" | tee -a ${LOG_FILE}
			echo "\t\tblcli_execute SmartServerGroup createGroup \"/Applications\" \"${CLEAN_APP}\" \"${CLEAN_APP}\" \"CMDB_APPLICATION\" \"equals\" \"Class://SystemObject/CMDB_Application/${CMDB_NAME}\"" | tee -a ${LOG_FILE}
			EXIT_CODE=2
	fi
	}

DeleteServerSmartGroup ()
	{
	SMARTGROUP=$1
	blcli_execute SmartServerGroup deleteGroupByQualifiedName "/Applications/${SMARTGROUP}" >/dev/null 2>/dev/null
	if test $? -eq 0; then
			echo "\t\tINFO: /Applications/${SMARTGROUP} has been deleted." | tee -a ${LOG_FILE}
		else
			echo "ERROR: There were problems deleting /Applications/${SMARTGROUP}." | tee -a ${LOG_FILE}
			EXIT_CODE=4
	fi
	}

FileCleanup ()
	{
	FILECLEAN=$1
#	echo "\nFILECLEAN >> ${FILECLEAN}"
	if test -f ${FILECLEAN}; then
		echo "Deleting: ${FILECLEAN}" >> ${LOG_FILE}
#		echo "rm ${FILECLEAN}" | tee -a ${LOG_FILE}
		rm ${FILECLEAN}
#		echo "_________________________________"
	fi
	}

GetDataLists ()
	{
	log_header_output GetDataLists | tee -a ${LOG_FILE}
	if ! test -d ${BLSERVER}/${WORK_PATH}; then
			echo "Creating ${BLSERVER}/${WORK_PATH}" | tee -a ${LOG_FILE}
			mkdir -p ${BLSERVER}/${WORK_PATH}
	fi
	if ! test -d ${BLSERVER}/${WORK_PATH}/logs; then
			echo "Creating ${BLSERVER}/${WORK_PATH}/logs" | tee -a ${LOG_FILE}
			mkdir -p ${BLSERVER}/${WORK_PATH}/logs
	fi
	FileCleanup ${SMARTGROUPS}
	FileCleanup ${BL_SERVER_GROUPS}
	FileCleanup ${BLSERVER}/${WORK_PATH}/CMDB_master.txt

	echo "cp -v //blfs/storage/bladmintmp/CMDB/CMDB_master.csv ${BLSERVER}/${WORK_PATH}/CMDB_master.txt"
	cp -v //blfs/storage/bladmintmp/CMDB/CMDB_master.csv ${BLSERVER}/${WORK_PATH}/CMDB_master.txt | tee -a ${LOG_FILE}

	echo "cat ${BLSERVER}/${WORK_PATH}/CMDB_master.txt"
	cat ${BLSERVER}/${WORK_PATH}/CMDB_master.txt | sed 's/Unknown\"AMR\"Unknown/Unknown/g' | sed 's/\[/++-/g' | sed 's/\]/+++/g' | sed 's/_/+-+/g' | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $2 }' | sort > ${CMDB_APPS}
	
	echo "blcli_execute ServerGroup listChildGroupsInGroup \"${SMARTGROUP_LIST}\""
	blcli_execute ServerGroup listChildGroupsInGroup "${SMARTGROUP_LIST}"  2>/dev/null >  ${TEMP_FILE_1}
	cat ${TEMP_FILE_1} | sort > ${SMARTGROUPS}
	
	echo "cat \"${SMARTGROUPS}\" | grep -v \"DEPRECATED CMDB_APPLICATION CIID's\" | sed 's/\[/++-/g' | sed 's/\]/+++/g' | sed 's/_/+-+/g' | sed 's/ /_/g' | sort"
	cat "${SMARTGROUPS}" | grep -v "DEPRECATED CMDB_APPLICATION CIID's" | sed 's/\[/++-/g' | sed 's/\]/+++/g' | sed 's/_/+-+/g' | sed 's/ /_/g' | sort > ${BL_SERVER_GROUPS}
	}

log_header_output ()
	{
	NAME_RUN=$1
	echo "\n________________________"
	echo "Executing: \"${NAME_RUN}\"\n"
	}

RemoveOldBLSmartgroups ()
	{
	log_header_output RemoveOldBLSmartgroups | tee -a ${LOG_FILE}
	SERVER_GROUPS=`cat ${BL_SERVER_GROUPS}`
	C_COUNT=`echo "${SERVER_GROUPS}" | wc | awk '{ print $1 }'`
	COUNT=${C_COUNT}
	for APP in ${SERVER_GROUPS}
		do
			RESULTS=`cat ${CMDB_APPS} | grep "${APP}"`
			if [ -z ${RESULTS} ]; then
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP} [DEPRECATED]" | tee -a ${LOG_FILE}
					DeleteServerSmartGroup "${CLEAN_APP}"
				else
					CLEAN_APP=`echo "${APP}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'`
					echo "${C_COUNT} of ${COUNT} - ${CLEAN_APP}" | tee -a ${LOG_FILE}
			fi
			C_COUNT=`expr ${C_COUNT} - 1`
		done
	}


UpdateServerProperties ()
	{
	log_header_output UpdateServerProperties | tee -a ${LOG_FILE}
	FileCleanup ${BL_SERVER_UPDATES}
	G_COUNT=`cat "${SMARTGROUPS}" | wc | awk '{ print $1}'`
	TG_COUNT=${G_COUNT}
		while IFS= read -r CMDB_APPLICATION_NAME
			do
				#echo "\n______________________________"
				#echo "${CMDB_APPLICATION_NAME}" | sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g'
				#echo "______________________________\n"
				#echo "cat ${CMDB_MASTER}| sed 's/++-/\[/g' | sed 's/+++/\]/g' | sed 's/_/ /g' | sed 's/+-+/_/g' | grep \"${CMDB_APPLICATION_NAME}\""
				#echo "cat ${CMDB_MASTER} | grep \"${CMDB_APPLICATION_NAME}\""
				CMDB_INFO=`cat ${CMDB_MASTER} | grep "${CMDB_APPLICATION_NAME}\""`
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
								#echo "\tNo servers found." | tee -a ${LOG_FILE}
							else
								COST_CENTER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $3 }'`
								CUSTOMER=`echo "${CMDB_INFO}" | sed 's/ /_/g' | sed 's/","/ /g' | awk '{ print $4 }' | sed 's/_/ /g'`
								#echo "\tCMDB_APPLICATION_NAME >> ${CMDB_APPLICATION_NAME}" | tee -a ${LOG_FILE}
								#echo "\tCOST_CENTER >> ${COST_CENTER}" | tee -a ${LOG_FILE}
								#echo "\tCUSTOMER >> ${CUSTOMER}" | tee -a ${LOG_FILE}
								S_COUNT=`echo "${SERVER_LIST}" | wc | awk '{ print $1}'`
								TS_COUNT=`echo "${SERVER_LIST}" | wc | awk '{ print $1}'`
								for LINE in ${SERVER_LIST}
									do
										echo "\t\tServer ${S_COUNT} of ${TS_COUNT} - ${LINE}" >> ${LOG_FILE}
										echo "\"${LINE}\",\"CMDB_APPLICATION_NAME\",\"${CMDB_APPLICATION_NAME}\"" >> ${BL_SERVER_UPDATES}
										echo "\"${LINE}\",\"COST_CENTER\",\"${COST_CENTER}\"" >> ${BL_SERVER_UPDATES}
										echo "\"${LINE}\",\"CUSTOMER\",\"${CUSTOMER}\"" >> ${BL_SERVER_UPDATES}
										S_COUNT=`expr ${S_COUNT} - 1`
									done
						fi
				fi
				G_COUNT=`expr ${G_COUNT} - 1`
				if test -f ${BL_SERVER_UPDATES}; then
					blcli Server bulkSetServerPropertyValues "/${WORK_PATH}" "BL_Server_Update.txt" >> ${LOG_FILE}
					if test $? -eq 0; then
							echo "\t${TS_COUNT} Servers updated." | tee -a ${LOG_FILE}
							#echo "\"INFO: ${CMDB_APPLICATION_NAME}\" server properties have been updated.\n" | tee -a ${LOG_FILE}
							FileCleanup ${BL_SERVER_UPDATES}
						else
							echo "\tERROR: There were issues with updating the server properties for \"${CMDB_APPLICATION_NAME}\"" | tee -a ${LOG_FILE}
							EXIT_CODE=2
					fi
				fi
			done < "${SMARTGROUPS}"
	}	
	
#	END of Functions
########################################################################

GetDataLists
RemoveOldBLSmartgroups
AddNewSmartgroups
GetDataLists
UpdateServerProperties

echo "EXIT_CODE >> ${EXIT_CODE}"
exit ${EXIT_CODE}