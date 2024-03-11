#!/bin/bash
################################################################################
##
## This script demonstrates the following workflow:
##
##   1. Search for genes based on Gene IDs
##   2. Perform a GO Enrichment Analysis on the search result
##   3. Download the analysis result as a tabular file
##
################################################################################
##
##  Configuration values below can be modified inline, or you may wish to edit
##  this script to make these parameters or read from environment variables.
##
################################################################################

#---------------------------------------------------------------
# script config
#---------------------------------------------------------------

webappUrl="https://plasmodb.org/plasmo"
cookieJar="./cookie-jar"
outputFile="./goEnrichmentResult.tsv"

#---------------------------------------------------------------
# search config
#---------------------------------------------------------------

geneIds="[\"PF3D7_1133400\"]" # JSON array (escape double quotes)

#---------------------------------------------------------------
# analysis config
#---------------------------------------------------------------

organism="Plasmodium falciparum 3D7"
ontologies="Biological Process"
evidenceCodes="[\\\"Computed\\\",\\\"Curated\\\"]" # JSON array (double escapes this time)
goSubset="No"
pValueCutoff="0.05"


################################################################################
##
##  Succession of CURL commands to download GO Enrichment result
##
################################################################################

#---------------------------------------------------------------
# establish a guest user and cookies needed to act as that user
#---------------------------------------------------------------

echo "Establishing guest user (creates cookie jar)"
curl -s -S -c $cookieJar \
     $webappUrl/service/users/current > /dev/null

#---------------------------------------------------------------
# create a dataset param ID containing specified gene IDs
#---------------------------------------------------------------

echo "Creating input dataset"
datasetData="{\"sourceType\":\"idList\",\"sourceContent\":{\"ids\":$geneIds}}"
datasetId=`curl -s -S -b $cookieJar \
     -X POST \
     -H "Content-Type:application/json" \
     -d "$datasetData" \
     $webappUrl/service/users/current/datasets | \
     jq .id`

#---------------------------------------------------------------
# create a step for this search's results
#---------------------------------------------------------------

echo "Creating search step"
stepData="{\"searchName\":\"GeneByLocusTag\",\"searchConfig\":{\"parameters\":{\"ds_gene_ids\":\"${datasetId}\"},\"wdkWeight\":10},\"customName\":\"IDs List\"}"
stepId=`curl -s -S -b $cookieJar \
     -X POST \
     -H "Content-Type:application/json" \
     -d "$stepData" \
     $webappUrl/service/users/current/steps | \
     jq .id`

#---------------------------------------------------------------
# create an analysis on this step
#---------------------------------------------------------------

echo "Creating analysis"
analysisData="{\"analysisName\":\"go-enrichment\",\"displayName\":\"Gene Ontology Enrichment\",\"parameters\":{\"organism\":\"${organism}\",\"goAssociationsOntologies\":\"${ontologies}\",\"goEvidenceCodes\":\"${evidenceCodes}\",\"goSubset\":\"${goSubset}\",\"pValueCutoff\":\"${pValueCutoff}\"}}"
analysisId=`curl -s -S -b $cookieJar \
     -X POST \
     -H "Content-Type:application/json" \
     -d "$analysisData" \
     $webappUrl/service/users/current/steps/$stepId/analyses | \
     jq .analysisId`

#---------------------------------------------------------------
# wait for analysis to complete
#---------------------------------------------------------------

while :; do
  echo "Checking analysis job status"
  jobStatus=`curl -s -S -b $cookieJar \
       $webappUrl/service/users/current/steps/$stepId/analyses/$analysisId/result/status | \
       jq .status`
  if [[ "$jobStatus" == '"RUNNING"' ]]; then
    echo "Job still running; checking again in 2 seconds"
    sleep 2
    continue
  fi
  if [[ "$jobStatus" == '"COMPLETE"' ]]; then
    echo "Job complete. Ready to download results."
    break
  fi
  echo "Job failed: $jobStatus"
  exit 1
done

#---------------------------------------------------------------
# download result
#---------------------------------------------------------------

echo "Results downloaded to $outputFile"
curl -s -S -b $cookieJar \
     -o $outputFile \
     $webappUrl/service/users/current/steps/$stepId/analyses/$analysisId/resources?path=hiddenGoEnrichmentResult.tsv

#---------------------------------------------------------------
# clean up cookie jar
#---------------------------------------------------------------

rm $cookieJar

echo "Done"

