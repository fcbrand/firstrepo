#!/bin/nsh
#
#######################################################################
#<doc>	NAME
#<doc>		CreateJavaProcessOutput.nsh
#<doc>	DESCRIPTION:
#<doc>		Sync CBS base card files
#<doc>	SCRIPT TYPE:
#<doc>		NSH Script 
#<doc>			#1 - Execute the script separately against each host (using "runscript")
#<doc>	SYNTAX:
#<doc>		./CreateJavaProcessOutput.nsh [FILE_AGE] [INV_PATH]
#<doc>	DIAGNOSTICS:
#<doc>		Exit code 0 if successful
#<doc>		Exit code 1 on failure
#<doc>		Exit code 2 on failure in process but not in full script.
#<doc>	OWNER:
#<doc>		Copyright (C) 2018 ZB, N.A.
########################################################################
#	DATE		MODIFIED BY		REASON FOR & DESCRIPTION OF MODIFICATION
#	--------	-------------	----------------------------------------
#	10/16/2018	Frank Brand		Written
#	10/18/2018	Frank Brand		Moved the file processing to BLFS.
#	10/25/2018	Fank Brand		Added Drive Letter checks.
########################################################################
#	Init variables

FILE_AGE=$1
INV_PATH=//blfs/storage/inventory
SERVER_FILES=${INV_PATH}/java_services
INV_FILE=${INV_PATH}/Java_Services.csv
#BLFS_FILE=${SERVER_FILES}/${TARGET}_Java_Services.txt

#	End Init variables
#######################################################################


SetFileHeader ()
	{
	LogHeaderOutput SetFileHeader
	echo "\"Server Name\",\"Service Account\",\"Java Path\",\"OS (BL)\",\"Environment (BL)\",\"CMDB Application Name (BL)\",\"System Owner (BL)\",\"Cost Center (BL)\"" > ${INV_FILE}
	}

ExtractData ()
	{
	LogHeaderOutput ExtractData
	SERVER_LIST=`nexec utlxa202 find /storage/inventory/java_services -type f -name '*_Java_Services.txt' -mtime -${FILE_AGE} | sed 's/\/storage\/inventory\/java_services\///g'| sed 's/_Java_Services.txt//g' | sort | uniq`
	COUNT=`echo "${SERVER_LIST}" | wc | awk '{ print $1 }'`
	LOOP_COUNT=1
	for TARGET in ${SERVER_LIST}
		do
			if [ -f "${SERVER_FILES}/${TARGET}_Java_Services.txt" ]; then
					echo "${LOOP_COUNT} of ${COUNT} - ${SERVER_FILES}/${TARGET}_Java_Services.txt"
					cat "${SERVER_FILES}/${TARGET}_Java_Services.txt" | sort | uniq | sed 's/^""/"/g' >> ${INV_FILE}
					if ! test $? -eq 0; then
							echo "ERROR: ${SERVER_FILES}/${TARGET}_Java_Services.txt"
							EXITCODE=1
					fi
				else
					echo "ERROR: ${SERVER_FILES}/${TARGET}_Java_Services.txt NOT FOUND"
			fi
			LOOP_COUNT=`expr ${LOOP_COUNT} + 1`
		done
	}

LogHeaderOutput ()
	{
	NAME_RUN=$1
	echo "________________________\nRunning ${NAME_RUN}:" | tee -a ${TEMP_PATH}${LOG_FILE}
	}

SetFileHeader
ExtractData

exit ${EXITCODE}

#nexec UTSQLT127 wmic process where "name='java.exe'" | grep -i java | sed 's/  /REALSPACE/g' | sed 's/\" /REALSPACE/g' | sed 's/ /+_+/g' | sed 's/REALSPACE/ /g' | awk '{ print $2   }'| sed 's/+_+/ /g' 