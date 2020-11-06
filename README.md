# LDCS
Lightweight Distributed Computing System repo 


This repo keeps:

1. the run time environments
2. the image pulling script
3. the production scripts used for LDCS production, collected per ldmx-sw release version.



### Run time environments

Let's assume we have ldmx-sw release `vX.Y.Z`

Copy the runtime environment matching the release number: `runTimeEnvironments/APPS-LDMX-X.Y.Z`

to where you keep them on your site, e.g. 

`cp runTimeEnvironments/APPS-LDMX-X.Y.Z /opt/arc-runtime/.`

Then enable it: `arcctl rte enable APPS/LDMX-X.Y.Z`


### Image building

Script: `images/build_from_docker.sh`

Again let's assume we have ldmx-sw release `vX.Y.Z`

Run with `bash /path/to/images/build_from_docker.sh vX.Y.Z`

in the directory where you want the image to end up. (Maybe `images` is a sensible place for them -- feel free to keep them there. They are too big to reasonably add them to github though.) This pulls a docker image from dockerhub and builds a singularity image from it. It might take a few minutes. Then point to it in the new runtime environment:

`arcctl rte params-set APPS-LDMX-X.Y.Z SINGULARITY_IMAGE /path/to/sigularityImage/beautiful-long-name-of-newly-created-singularity-image.sif`

For fun, double check the parameters:
`arcctl rte params-get APPS-LDMX-X.Y.Z`
