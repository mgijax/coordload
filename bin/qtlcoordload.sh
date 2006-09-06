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
#      - Common configuration file (/usr/local/mgi/etc/common.config.sh)
#      - Coordinate load configuration file
#      - Coordinate load input file
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
LOG=`pwd`/coordload.log
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
#  Establish the common configuration file name
#
CONFIG_COMMON=`pwd`/common.config.sh

#
#  Make sure the common configuration file readable.
#
if [ ! -r ${CONFIG_COMMON} ]
then
    echo "Cannot read configuration file: ${CONFIG_COMMON}" | tee -a ${LOG}
    exit 1
fi

#
# Source the common configuration file
#
. ${CONFIG_COMMON}

#
#  Establish the master configuration file name
#
CONFIG_MASTER=${MGICONFIG}/master.config.sh

#
#  Make sure the master config configuration file readable.
#
if [ ! -r ${CONFIG_MASTER} ]
then
    echo "Cannot read configuration file: ${CONFIG_MASTER}" | tee -a ${LOG}
    exit 1
fi

#
# Source the master configuration file
#
. ${CONFIG_MASTER}

#
# Make sure command line config files are readable and source
#
echo "command line params: $@"
config_files="${CONFIG_COMMON},${CONFIG_MASTER}"
for config in $@
do
    if [ ! -r ${config} ]
    then
        echo "Cannot read configuration file: ${config}" | tee -a ${LOG}
        exit 1
    fi
    config_files="${config_files},${config}"
    echo "config_files: ${config_files}"
    . ${config}
done

echo "javaruntime:${JAVARUNTIMEOPTS}"
echo "classpath:${CLASSPATH}"
echo "dbserver:${MGD_DBSERVER}"
echo "database:${MGD_DBNAME}"

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

#
# check that INFILE_NAME has been set and readable
#
if [ "${INFILE_NAME}" = "" ]
then
     # set STAT for endJobStream.py called from postload in shutDown
    STAT=1
    echo "INFILE_NAME not defined. Return status: ${STAT}" | \
        tee -a ${LOG_DIAG}
    shutDown
    exit 1
fi

if [ ! -r ${INFILE_NAME} ]
then
    # set STAT for endJobStream.py called from postload in shutDown
    STAT=1
    echo "Cannot read from input file: ${INFILE_NAME}" | tee -a ${LOG}
    shutDown
    exit 1
fi

#
#  Function that performs cleanup tasks for the job stream prior to
#  termination.
#
shutDown ()
{
    #
    # report location of logs
    #
    echo "\nSee logs at ${LOGDIR}\n" >> ${LOG_PROC}

    #
    # call DLA library function
    #
    postload

}

#
# Function that runs to java load
#

run ()
{
    #
    # log time and input files to process
    #
    echo "\n`date`" >> ${LOG_PROC}
    #
    # run coordload
    #
    ${JAVA} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} \
	-DCONFIG=${config_files} \
	-DJOBKEY=${JOBKEY} ${DLA_START}

    STAT=$?
    if [ ${STAT} -ne 0 ]
    then
	echo "coordload processing failed.  \
	    Return status: ${STAT}" >> ${LOG_PROC}
	shutDown
	exit 1
    fi
    echo "coordload completed successfully" >> ${LOG_PROC}


}

##################################################################
# main
##################################################################

#
# createArchive including OUTPUTDIR, startLog, getConfigEnv, get job key
#
preload ${OUTPUTDIR}

#
# rm files and dirs from OUTPUTDIR and RPTDIR
#

cleanDir ${OUTPUTDIR} ${RPTDIR}

#
# Run the assembly coordinate load
#

echo "Running coordload" | tee -a ${LOG_DIAG} ${LOG_PROC}

# log time and input files to process
echo "\n`date`" >> ${LOG_PROC}

echo "Processing input file ${INFILE_NAME}" | tee -a ${LOG_DIAG} ${LOG_PROC}

run

echo "Running noteload" | tee -a ${LOG_DIAG} ${LOG_PROC}

# log time and input files to process
echo "\n`date`" >> ${LOG_PROC}
${NOTELOAD_SH} ${NOTELOADCONFIG} >> ${LOG_PROC}
STAT=$?
checkStatus ${STAT} "${ASSOCLOADER_SH}"

#
# run postload cleanup and email logs
#
shutDown

exit 0

