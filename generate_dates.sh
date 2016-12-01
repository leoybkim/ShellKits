#!/bin/bash


# ------------------------------------------------------------------
#          generate_dates
#
#          This script generates future dates in tab separated list
#          Use LOAD DATA INFILE to import into mysql table
#
#          Date range: $START_YEAR-01-01 ~ $END_YEAR-12-31
#
#          DAY | WEEK | MONTH | QUARTER | YEAR
#
# ------------------------------------------------------------------



# Default start and end year
START_YEAR=$(date --date now+1years +'%Y')
END_YEAR=$(date --date now+13years +'%Y')


# Option
function usage
{
  echo "Usage: $0 [-s <START_YEAR>] [-e <END_YEAR>]"
}

while getopts s:e:h c ; do
  case $c in
    s) START_YEAR="${OPTARG}" ;;
    e) END_YEAR="${OPTARG}" ;;
    h) usage ; exit 0 ;;
    *) usage ; exit 2 ;;
  esac
done


START_DATE="${START_YEAR}-01-01"
END_DATE="${END_YEAR}-12-31"

# Variable for generating weeks
FIRST_SUNDAY=$(date -d "${START_DATE} -$(date -d ${START_DATE} +%w) days" +'%Y-%m-%d')
LAST_SUNDAY=$(date -d "${END_DATE} -$(date -d ${END_DATE} +%w) days" +'%Y-%m-%d')
SUNDAY=$FIRST_SUNDAY

if [[ "${FIRST_SUNDAY}" < "${START_DATE}" ]] ; then
  SUNDAY=$(date --date $FIRST_SUNDAY+7days +'%Y-%m-%d')
fi


# Log variables
PRG=$(basename $0 | awk -F . '{print $1}')
LOGS=/home/mysql/logs
TMP=/tmp/${PRG}
O_DATES=${TMP}.o_dates
O_WEEKS=${TMP}.o_weeks
O_MONTHS=${TMP}.o_months
O_QUARTERS=${TMP}.o_quarters
O_YEARS=${TMP}.o_years
STATS_DATES=${LOGS}/stats_dates.lst

# Clean up on exit
trap 'rm -f ${TMP}*' 0 1 2 3 9 15 19 23 24


# Debugging
#rm -f $O_DATES $O_WEEKS $O_MONTHS $O_QUARTERS $O_YEARS



#######################################
# Calc number of days between 2 dates
# 60*60*24 = 86400 seconds in day
# Arguments:
#  $1:  First date
#  $2: Second date
# Return Value:
#  diff_days
#######################################
function diff_day
{
  d1=$(date -d "$1" +%s)
  d2=$(date -d "$2" +%s)
  echo "$(( (d1 - d2) / 86400 ))"
}


#######################################
# Column "Day" for stats_dates table
# Arguments:
#  $1: Year
#  $2: Month
#  $3: Day
#######################################
function gen_day
{
  echo "${1}-${2}-${3} 00:00:00" >> $O_DATES
}


#######################################
# Column "Week" for stats_dates table
#######################################
function gen_week
{
  V_SUNDAY=$SUNDAY

  # Sync first few Sundays
  if [[ "${V_SUNDAY}" > "${START_DATE}" ]] ; then
    # Number of days that needs to be calibrated
    diff_days=$(diff_day $V_SUNDAY $START_DATE)
    for day in $(seq -w 1 $diff_days) ; do
      echo "$FIRST_SUNDAY 00:00:00" >> $O_WEEKS
    done
  fi

  # Generate weeks
  while [[  "${V_SUNDAY}" < "${LAST_SUNDAY}" ]] ; do
    for i in $(seq 1 7); do
      echo "$V_SUNDAY 00:00:00" >> $O_WEEKS
    done
    V_SUNDAY=$(date --date ${V_SUNDAY}+1weeks +'%Y-%m-%d')
  done

  # Sync last few Sundays
  if [[ "${V_SUNDAY}" == "${LAST_SUNDAY}" ]] ; then
      # Number of days that needs to be calibrated
      diff_days=$(diff_day $END_DATE $LAST_SUNDAY)
      for day in $( seq -w 0 $diff_days ) ; do
        echo "$V_SUNDAY 00:00:00" >> $O_WEEKS
      done
  fi
}


#######################################
# Column "Month" for stats_dates table
# Arguments:
#  $1: Year
#  $2: Month
#######################################
function gen_month
{
  echo "${1}-${2}-01 00:00:00" >> $O_MONTHS
}



#######################################
# Column "Year" for stats_dates table
# Arguments:
#  $1: Year
#  $2: Month
#######################################
function gen_quarter
{
  if [[ "${2}" == "01" || "${2}" == "02" || "${2}" == "03" ]] ; then
    echo "${1}-01-01 00:00:00" >> $O_QUARTERS
  elif [[ "${2}" == "04" || "${2}" == "05" || "${2}" == "06" ]] ; then
    echo "${1}-04-01 00:00:00" >> $O_QUARTERS
  elif [[ "${2}" == "07" || "${2}" == "08" || "${2}" == "09" ]] ; then
    echo "${1}-07-01 00:00:00" >> $O_QUARTERS
  else
    echo "${1}-10-01 00:00:00" >> $O_QUARTERS
  fi
}



#######################################
# Column "Year" for stats_dates table
# Arguments:
#  $1: Year
#######################################
function gen_year
{
  echo "${1}-01-01 00:00:00" >> $O_YEARS
}







############## START ##################


# DAY  MONTH  QUARTER  YEAR
echo "Generating dates ..."
for year in $(seq -w $START_YEAR $END_YEAR); do
  for month in $(seq -w 01 12); do
    # leap year -> worst idea ever
    for day in $(seq -w 01 $(cal $month $year | awk 'NF {DAYS=$NF}; END {print DAYS}')); do
      gen_day $year $month $day
      gen_month $year $month
      gen_quarter $year $month
      gen_year $year
    done
  done
done



# WEEK
gen_week


# COLLAGE COLUMNS to tab separated value
echo "Collaging into tab separated list ..."
paste $O_DATES $O_WEEKS $O_MONTHS $O_QUARTERS $O_YEARS > $STATS_DATES


echo "Done!"
echo "Grab your file from $STATS_DATES"