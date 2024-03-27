#!/bin/bash

aws omics create-workflow \
    --name willyn_cellranger_v5 \
    --description "willyn cellranger" \
    --definition-zip fileb://cellranger.zip \
    --main cellranger_workflow.wdl \
    --parameter-template file://workflow-parameters.json 
   