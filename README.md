# LDCS
Lightweight Distributed Computing System repo 


This repo keeps:

1. the run time environments
2. the image pulling script
3. the production scripts used for LDCS production, collected per ldmx-sw release version.



### Run time environments

Copy the runtime environment matching the release number: `runTimeEnvironments/APPS-LDMX-X.Y.Z`
to where you keep them on your site, e.g. `cp runTimeEnvironments/APPS-LDMX-X.Y.Z /opt/arc-runtime/.`

Then enable it: `arcctl rte enable APPS/LDMX-X.Y.Z`


### Image building

Script: `images/build_from_docker.sh`
Let's assume we have ldmx-sw release vX.Y.Z

Run with `bash /path/to/build_from_docker.sh vX.Y.Z'
in the directory where you want the image to end up. Then point to it in the new runtime environment:

`arcctl rte params-set APPS-LDMX-X.Y.Z SINGULARITY_IMAGE /path/to/sigularityImage/beatiful-long-name-of-newly-created-singularity-image.sif`

For fun, double check the parameters:
`arcctl rte params-get APPS-LDMX-X.Y.Z`