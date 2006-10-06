#!/bin/sh
#
#  qtlcoordload.sh
###########################################################################
#
#  Purpose:  This script controls the execution of the QTL Coordinate Load
#
   Usage="qtlcoordload.sh config_file [config_file2 ... config_fileN]"
#
#  Env Vars:
#
#      See the configuration file
#
#  Inputs:
#
#      - Common configuration file  - 
#	    /usr/local/mgi/live/mgiconfig/master.config.sh
#      - QTL Coordinate load configuration file
#      - QTL Coordinate load input file
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_DIAG}, ${LOG_CUR} and ${LOG_VAL}
#      - BCP files for for inserts to each database table to be loaded
#      - Records written to the database tables
#      - Exceptions written to standard error
#      - Configuration and initialization errors are written to a log file
#        for the shell script
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#      2:  Non-fatal error occurred
#
#  Assumes:  Nothing
#
#  Implementation:  
#
#  Notes:  None
#
###########################################################################

#
#  Set up a log file for the shell script in case there is an error
#  during configuration and initialization.
#
cd `dirname $0`/..
LOG=`pwd`/qtlcoordload.log
rm -f ${LOG}

#
#  Verify the argument(s) to the shell script.
#
if [ $# -lt 1 ]
then
    echo ${Usage} | tee -a ${LOG}
    exit 1
fi

#
# Make sure command line config files are readable and source
#
echo "command line params: $@"

# there will always be one argument
config_files=$1
shift
. ${config_files}

while [ "$1" != "" ]
do
    config=$1
    . ${config} 
    config_files="${config_files},${config}"
    shift
done

#
#  Source the DLA library functions.
#
if [ "${DLAJOBSTREAMFUNC}" != "" ]
then
    if [ -r ${DLAJOBSTREAMFUNC} ]
    then
        . ${DLAJOBSTREAMFUNC}
    else
        echo "Cannot source DLA functions script: ${DLAJOBSTREAMFUNC}"
        exit 1
    fi
else
    echo "Environment variable DLAJOBSTREAMFUNC has not been defined."
fi

echo "\n`date`" >> ${LOG_DIAG} ${LOG_PROC}
echo "Running qtl coordload" | tee -a ${LOG_DIAG} ${LOG_PROC}
${COORDLOAD}/bin/coordload.sh ${config_files}
STAT=$?
checkStatus ${STAT} "${COORDLOAD}/bin/coordload.sh"

echo "\n`date`" >> ${LOG_DIAG} ${LOG_PROC}
echo "Running qtl noteload" | tee -a ${LOG_DIAG} ${LOG_PROC}
${NOTELOAD_SH} ${NOTELOADCONFIG} | tee -a ${LOG_DIAG} ${LOG_PROC}
STAT=$?
checkStatus ${STAT} "${NOTELOAD_SH}"

exit 0

