# LDCS
Lightweight Distributed Computing System repo 


This repo keeps:

1. the run time environments
2. the image pulling script
3. the production scripts used for LDCS production, collected per ldmx-sw release version.
4. the helper scripts used on the act machine for job submission



## Setting up a new SIMPROD RTE:

Copy the runtime environment you want: `runTimeEnvironments/LDMX-SIMPROD-x.y`

to where you keep them on your site, e.g. 

`cp runTimeEnvironments/LDMX-SIMPROD-x.y /opt/arc-runtime/APPS/LDMX-SIMPROD-x.y`

**Note** that these are LDCS specific files, so version numbers are *independent* of `ldmx-sw` versions. 

Then enable it: `arcctl rte enable APPS/LDMX-SIMPROD-x.y`


#### Setting the local storage path 

`arcctl rte params-set APPS/LDMX-SIMPROD-x.y LDMX_STORAGE_BASE /your/local/storage/path/`


#### Opting to keep a local copy of job output (available from version 3.0)
`arcctl rte params-set APPS/LDMX-SIMPROD-x.y KEEP_LOCAL_COPY Y`

This keeps a copy of job output in the local storage path. If `KEEP_LOCAL_COPY` is left empty (default), a local copy of job outout won't be kept. Job output is transferred to the final storage location (over GridFTP) regardless. 


## Setting up an image RTE for a new ldmx-sw release/image

Let's assume we have ldmx-sw release `vX.Y.Z`

Copy the runtime environment matching the release number: `runTimeEnvironments/LDMX-X.Y.Z`

to where you keep them on your site, e.g. 

`cp runTimeEnvironments/LDMX-X.Y.Z /opt/arc-runtime/APPS/LDMX-X.Y.Z`

Then enable it: `arcctl rte enable APPS/LDMX-X.Y.Z`

Next: instructions on how to build the corresponding new image.


### Image building

Script: `images/build_from_docker.sh`

Again let's assume we have ldmx-sw release `vX.Y.Z`

Run with `bash /path/to/LDCS/images/build_from_docker.sh vX.Y.Z [optional: repo name]`

in the directory where you want the image to end up. (Maybe `images` is a sensible place for them -- feel free to keep them there. They are too big to reasonably add them to github though.) This pulls a docker image from dockerhub and builds a singularity image from it. It might take a few minutes. Then point to it in the new runtime environment (after following RTE setup instructions above):

`arcctl rte params-set APPS/LDMX-X.Y.Z SINGULARITY_IMAGE /path/to/beautiful-long-name-of-newly-created-singularity-image.sif`

For fun, double check the parameters:
`arcctl rte params-get APPS/LDMX-X.Y.Z`



## Checking the RTE parameters 
`arcctl rte params-get APPS/LDMX-SIMPROD-x.y`

`arcctl rte params-get APPS/LDMX-X.Y.Z`

## Checking which RTEs are enabled
`arcctl rte list`
