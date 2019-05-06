##!/bin/bash
#
# Function to get the latest content-view version
latest_cv_version(){
  cv_id="$1"
  cv_latest_version=$(hammer --csv content-view version list --content-view-id $cv_id --organization $org |awk -F, '{print $3}'|sort -nr | head -n1)
  echo "Newest content-view version: $cv_latest_version"
}

# Fuction to get the latest composite content-view latest_version
latest_ccv_version(){
  ccv_id="$1"
  ccv_latest_version=$(hammer --csv content-view version list --content-view-id $ccv_id --organization $org |awk -F, '{print $3}'|sort -nr | head -n1)
  echo "Newest Composite content-view version: $ccv_latest_version"
}

## This section loops over the Content-view ID's and publishes them
## After publishing task is complete, it then loops through the life-cycle
## environment to promote them to the Production environment
publish_content_views(){
  for id in ${cv_id[@]}; do
    echo "---- publishing contentview ID $id ----"
    hammer content-view publish --id $id --organization $org --description "published on $(/usr/bin/date -d now)"
  done
}

# Promote content-views
promote_content_views(){
  for id in ${cv_id[@]}; do
    latest_cv_version $id
    for lc in ${lc_env[@]}; do
      lc_env_ID=$(echo $lc | awk -F, {'print $1'})
      lc_env_NAME=$(echo $lc | awk -F, {'print $2'})
      echo "---- promoting contentview ID $id version $cv_latest_version to $lc_env_NAME  ----"
      hammer content-view version promote --organization $org --to-lifecycle-environment $lc_env_NAME --content-view-id $id --version $cv_latest_version --description "promoted on $(/usr/bin/date -d now)"
    done
  done
}

## After publishing task is complete, it then loops through the life-cycle
## environment to promote them to the Production environment
publish_composite_content_views(){
  for id in ${ccv_id[@]}; do
    echo "---- publishing contentview ID $id ----"
    hammer content-view publish --id $id --organization $org --description "published on $(/usr/bin/date -d now)"
  done
}

# Promote composite content-views
promote_composite_content_views(){
  for id in ${ccv_id[@]}; do
    latest_ccv_version "$id"
    for env in ${lc_env[@]}; do
      lc_env_ID=$(echo $env | awk -F, {'print $1'})
      lc_env_NAME=$(echo $env | awk -F, {'print $2'})
      echo "---- promoting composite contentview ID $id from $ccv_latest_version to $lc_env_NAME ----"
      hammer content-view version promote --organization $org --to-lifecycle-environment $lc_env_NAME --content-view-id $id --version $ccv_latest_version --description "promoted on $(/usr/bin/date -d now)"
    done
  done
}

# removing old composite content-views and only keeping the latest versions based on the retain_cv value
purge_composite_content_views(){
  for id in ${ccv_id[@]}; do
    latest_ccv_version "$id"
    int_ccv_latest_version=$(echo $ccv_latest_version|cut -d '.' -f 1)
    int_ccv_last_version_keep=$((int_ccv_latest_version - retain_cv))
    ccv_versions=($(hammer --csv content-view version list --organization $org --content-view-id $id | grep -v ^ID | sort -nr | awk -F, {'print $3'}))
    for version in ${ccv_versions[@]}; do
      int_version=$(echo $version|cut -d '.' -f 1 )
      if [[ $int_version -lt $int_ccv_last_version_keep ]]; then
         echo "removing content version $version from $id"
         hammer content-view version delete --organization $org --content-view-id $id --version $version
      fi
    done
  done
}

# removing old content-views and only keeping the latest versions based on the retain_cv value
purge_content_views(){
  for id in ${cv_id[@]}; do
    latest_cv_version "$id"
    int_cv_latest_version=$(echo $cv_latest_version|cut -d '.' -f 1)
    int_cv_last_version_keep=$((int_cv_latest_version - retain_cv))
    cv_versions=($(hammer --csv content-view version list --organization $org --content-view-id $id | grep -v ^ID | sort -nr | awk -F, {'print $3'}))
    for version in ${cv_versions[@]}; do
      int_version=$(echo $version|cut -d '.' -f 1 )
      if [[ $int_version -lt $int_cv_last_version_keep ]]; then
        echo "removing content version $version from $id"
        hammer content-view version delete --organization $org --content-view-id $id --version $version
      fi
    done
  done
}
# script help function
usage(){
  echo "Usage:"
  echo "-o <satellite organization>"
  echo "-r <content view version max number to retain>"
  exit 1
}
### MAIN secition of script
while getopts ":o:r:" option
do
  case $option in
    o)
      org=$OPTARG
      ;;
    r)
      retain_cv=$OPTARG
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [[ -z $org ]] && [[ -z $retain_cv ]] ; then
  echo "Error:Set both -r and -o arguments"
  usage
else
  ## Collecting all Content View ID number
  cv_id=($(hammer --csv content-view list --organization $org --composite no | grep -v "Default Organization View" | awk -F, '{print $1}' | grep '^[0-9]'| sort -n))

  ## Collecting all Composite Content View ID number
  ccv_id=($(hammer --csv content-view list --organization $org --composite yes | awk -F, '{print $1}' | grep '^[0-9]'| sort -n))

  ## Collecting all lifecycle-environment ID number
  lc_env=($(hammer --csv lifecycle-environment list --organization $org| grep -vi '^ID' | grep -vi '^1'| sort -n))
  ## Call the functions
  publish_content_views
  promote_content_views
  publish_composite_content_views
  promote_composite_content_views
  purge_composite_content_views
  purge_content_views
fi
exit 0;
