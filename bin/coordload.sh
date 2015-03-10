#!/bin/sh
#
#  coordload.sh
###########################################################################
#
#  Purpose:  This script controls the execution of the Coordinate Loads
#
   Usage="coordload.sh config_file [config_file2 ... config_fileN]"
#
#  Env Vars:
#
#      See the configuration file
#
#  Inputs:
#
#      - Common configuration file  - 
#		/usr/local/mgi/live/mgiconfig/master.config.sh
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
# Make sure command line config files are readable and source
#

# there will always be one argument
config_files=$1
shift
. ${config_files}

while [ "$1" != "" ]
do
    config=$1
    echo ${config}
    . ${config}
    config_files="${config_files},${config}"
    shift
done

#
#  Make sure the master configuration file is readable
#

if [ ! -r ${CONFIG_MASTER} ]
then
    echo "Cannot read configuration file: ${CONFIG_MASTER}"
    exit 1
fi

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
     # set STAT for endJobStream.py 
    STAT=1
    checkStatus ${STAT} "INFILE_NAME not defined"
fi

if [ ! -r ${INFILE_NAME} ]
then
    # set STAT for endJobStream.py 
    STAT=1
    checkStatus ${STAT} "Cannot read from input file: ${INFILE_NAME}"
fi

#
# Function that runs to java load
#

run ()
{
    #
    # log time and input files to process
    #
    echo "" >> ${LOG_PROC}
    echo "`date`" >> ${LOG_PROC}
    #
    # run coordload
    #
    ${JAVA} ${JAVARUNTIMEOPTS} -classpath ${CLASSPATH} \
	-DCONFIG=${CONFIG_MASTER},${config_files} \
	-DJOBKEY=${JOBKEY} ${DLA_START}

    STAT=$?
    checkStatus ${STAT} "${COORDLOAD}/bin/coordload.sh"
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
echo "" >> ${LOG_DIAG} ${LOG_PROC}
echo "`date`" >> ${LOG_DIAG} ${LOG_PROC}

echo "Processing input file ${INFILE_NAME}" \
     >> ${LOG_DIAG} ${LOG_PROC}

run

#
# run postload cleanup and email logs
#
shutDown

exit 0
