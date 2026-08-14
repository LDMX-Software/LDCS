#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import argparse
import sys
import os
import json
import hashlib
import zlib
import time

#json parsing is in a separate file 
from parseJSON import build_record_from_inputs, flatten_json, make_record

# logging
logger = logging.getLogger('LDMX.SimProd.Helper')
logger.setLevel(logging.INFO)
log_handler_stderr = logging.StreamHandler()
log_handler_stderr.setFormatter(
    logging.Formatter('[%(asctime)s] [%(name)s] [%(levelname)s] [%(process)d] [%(message)s]'))
logger.addHandler(log_handler_stderr)

# read ldmx.config to dict
def parse_ldmx_config(config='ldmxjob.config'):
    conf_dict = {}
    with open(config, 'r') as conf_f:
        for line in conf_f:
            kv = line.split('=', 2)
            if len(kv) != 2:
                logger.error('Malformed %s line: %s', config, line)
                continue
            conf_dict[kv[0]] = kv[1].strip()
    # split physics process from config
    if not 'PhysicsProcess' in conf_dict: 
        logger.error('PhysicsProcess is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    # ensure both random seeds are set
#    if 'RandomSeed1' not in conf_dict or 'RandomSeed2' not in conf_dict:
#        logger.error('RandomSeed1 and/or RandomSeed2 is not set in %s. Job aborted.', config)
#        sys.exit(1)
    # ^^ no longer mandatory options
    for opt in ['DetectorVersion'] : #, 'FieldMap']: #don't think fieldmap is actually necessary anymore 
        if opt not in conf_dict :
            if 'APrimeMass' in conf_dict: # don't need detector details for pure event library generation jobs 
                conf_dict[opt] = None     # just set to empty to avoid missing field later
            else :
                logger.error('%s is not defined in the %s. Job aborted.', opt, config)
                sys.exit(1)
    # ensure FileName is set to something
    if 'FileName' not in conf_dict:
        conf_dict['FileName'] = 'output.sif'
    #batch id will be used for storage directory structure. Should ALWAYS be set.
    if 'BatchID' not in conf_dict:
        logger.error('BatchID is not defined in the %s. Needed for storage directory structure. Job aborted.', config)
        sys.exit(1)

    return conf_dict

# read ldmx.config to dict
def parse_ldmx_imagebuild_config(config='ldmxjob.config'):

    logger.info('In image building config parsing funcion')
    conf_dict = {}
    with open(config, 'r') as conf_f:
        for line in conf_f:
            kv = line.split('=', 2) 
            if len(kv) != 2:
                logger.error('Malformed line %s in config %s', line, config)
                continue
            conf_dict[kv[0]] = kv[1].strip()
    #some stuff is mandatory 
    if not 'FileName' in conf_dict:
        logger.error('Output image name ("FileName") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    if not 'DockerRepo' in conf_dict:
        logger.error('DockerHub repository ("DockerRepo") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    if not 'DockerTag' in conf_dict:
        logger.error('DockerHub container tag ("DockerTag") is not defined in the %s. Job aborted.', config)
        sys.exit(1)
    if not 'UserID' in conf_dict:
        logger.error('aCT user ID ("UserID") is not defined in the %s. Job aborted.', config)
        sys.exit(1)

    #we made it this far. admit that we're building an image
    conf_dict['IsImage']=='True'

    return conf_dict

def print_eval(conf_dict, makeSingImage=False):
    if makeSingImage :
        printString= ('export DOCKER_REPO="{DockerRepo}"\n'
                      'export DOCKER_TAG="{DockerTag}"\n'
                      'export OUTPUTDATAFILE="{FileName}"'.format(**conf_dict))
    else :
        printString= ('export DETECTOR="ldmx-det-full-v{DetectorVersion}-fieldmap-magnet"\n'
                      'export OUTPUTDATAFILE="{FileName}"'.format(**conf_dict))
        if "FieldMap" in conf_dict : 
            printString+=('\nexport FIELDMAP="{FieldMap}"'.format(**conf_dict))

        if 'APrimeMass' in conf_dict :
            printString+=('\nexport APMASS="{APrimeMass}"\n'
                          'export NEVENTS="{NumberOfEvents}"\n'
                          'export RUNNB="{runNumber}"\n'
                          'export ENERGIES="{IncidentEnergies}"'
                          .format(**conf_dict))
    if "ImageLocationLocal" in conf_dict :
        printString+=('\nexport SINGULARITY_IMAGE="{ImageLocationLocal}"\n'.format(**conf_dict))

    print( printString )


def calculate_md5_adler32_checksum(file, chunk_size=524288):
    md5 = hashlib.md5()
    adler32 = 1
    with open(file, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            md5.update(chunk)
            adler32 = zlib.adler32(chunk, adler32) & 0xffffffff
    return (md5.hexdigest(), '{:08x}'.format(adler32))

def collect_from_json( infile, in_conf ):
    #function to convert json nested list to flat metadata list 
    config_dict = {}

    #get a minimum of info from production config to return in the case the parameter dump wasn't created (like v1.7 running)
    isRecon = False 
    isTriggerSkim = False 
    isBDTSkim = False 
    if in_conf.get("IsTriggerSkim") :
        if in_conf.get("IsTriggerSkim") == "Yes" :
            isTriggerSkim=True
    if in_conf.get("IsBDTSkim") :
        if in_conf.get("IsBDTSkim") == "Yes" :
            isBDTSkim=True
    if in_conf.get("IsRecon") :
        if in_conf.get("IsRecon") == "Yes" :
            isRecon=True
    if in_conf.get("InputFilesPerJob") :
        config_dict["NumberInputFiles"] = in_conf.get("InputFilesPerJob")
    config_dict['IsRecon'] = isRecon
    config_dict['IsTriggerSkim'] = isTriggerSkim
    config_dict['IsBDTSkim'] = isBDTSkim

    try:
        with open(infile, "r") as jf :
            mjson = json.load(jf)
    except Exception as e:
        logger.error('Failed to open {}: {}'.format(infile, str(e)))
        return config_dict 
#        sys.exit(1)

    logger.info('Opened {}'.format(infile))
    logger.debug(json.dumps(mjson, indent = 2, sort_keys=True ))

    
    # once we have parsed the arc job config, we should parse the ldmx-sw parameter dump and add it to the dict

    #######-------------------------------------#########
    #######-------------------------------------#########
    # insert new parsing method here 
    #
    #
    # this means: pass some jsons to the json recursing parser fct
    # and populate the metadata dict that way
    # the parameter dump out from the job only contains ldmx-sw parameter settings 
    # --> make sure that stuff from batch configs, and ARC metadata such as walltime
    # or site, and booleans such as isTriggerSkim or isRecon are still added 
    #######-------------------------------------#########
    #######-------------------------------------#########

    #we basically need 

    
    
    
    isRecon = False #allow for checking this from parameter dump, if one exists
    # put some logic in here for isRecon, or, from now on enforce that it's set in the
    # job submission config 
    for seq in mjson['sequence'] :
        procName=seq['className'].split('::')[1]  #remove namespace 
        if procName != "Simulator" :  #everything except simulation is reconstruction
            isRecon = True 

    det = 'v{DetectorVersion}'.format(**in_conf)

    config_dict['IsRecon'] = isRecon


    
    logger.debug(json.dumps(config_dict, indent = 2, sort_keys=True ))
    return config_dict


def job_starttime(starttime_f='.ldmx.job.starttime'):
    if os.path.exists(starttime_f):
        with open(starttime_f, 'r') as fd:
            return int(fd.read())
    else:
        current_time = int(time.time())
        with open(starttime_f, 'w') as fd:
            fd.write('{0}'.format(current_time))
            return current_time

def set_remote_output(conf_dict, meta):
    # Check for remote location and construct URL
    # GRID_GLOBAL_JOBHOST is available from ARC 6.8
    cehost = os.environ.get('GRID_GLOBAL_JOBHOST')
    with open('output.files', 'w') as f:
        if 'FinalOutputDestination' in conf_dict and 'FinalOutputBasePath' in conf_dict \
        and cehost not in conf_dict.get('NoUploadSites', '').split(','):
            filepath=""
            if 'IsEventLibrary' in meta and meta['IsEventLibrary']=='True' :
                filepath = '/{Scope}/{BeamEnergy}GeV/{BatchID}'.format(**meta)
            elif 'IsImage' in meta and (meta['IsImage']=='True' or conf_dict['IsImage']=='Yes') :
                filepath = '/{UserID}/{Scope}/{BatchID}'.format(**meta)
            else :
                filepath += '/{Scope}/v{DetectorVersion}/{BeamEnergy}GeV/{BatchID}'.format(**meta)
            pfn = conf_dict['FinalOutputBasePath']
            while pfn.endswith('/'):
                pfn = pfn[:-1]
            pfn += filepath+'/{name}'.format(**meta)
            meta['remote_output'] = {'rse': conf_dict['FinalOutputDestination'],
                                    'pfn': pfn}
            meta['DataLocation'] = pfn

            # If the "remote" site is actually local, skip uploading over gridftp,
            # after registering it with that url for other jobs to retrieve
            siteName=conf_dict['FinalOutputDestination'].split("_")[0].lower()
            logger.info("From output dest %s, got site name %s", conf_dict['FinalOutputDestination'], siteName)
            if siteName in cehost.lower() :
                filepath=os.environ['LDMX_STORAGE_BASE']+filepath
                pfn=filepath+'/{name}'.format(**meta)
                logger.info("At site %s, doing local copy of output file %s to final output destination", siteName, pfn )
                os.system('mkdir -p '+filepath)
                os.system('cp '+conf_dict['FileName']+' '+pfn)
            else :
                # Add to ARC output list
                f.write('{} {}'.format(conf_dict['FileName'], pfn))

def get_local_copy(conf_dict):
    for infile in conf_dict['InputDataLocationLocal'].split(",") : 
        logger.info("Copying local input file %s", infile )
        os.system('cp '+infile+' .')
        logger.info("Copied local input file %s to node", infile.split("/")[-1] )
    return

def get_pileup_file(conf_dict):
    fname=conf_dict['PileupFile'].split(":")[1]
    fullPath=conf_dict['PileupLocationLocal']
    logger.info("Dir contents before attempting to copy pileup file:")
    os.system('ls -lh')
    os.system('cp '+fullPath+' '+fname)
    logger.info("Dir contents after attempting to copy pileup file:")
    os.system('ls -lh')
    logger.info("Copied pileup file to node")
    return


def collect_image_meta( conf_dict, imageMeta):

    meta = {}
    meta['IsImage'] = True
    meta['IsSimulation'] = False
    meta['IsRecon'] = False
    # rucio specifics
    for fromconf in ['Scope', 'SampleId', 'UserID', 'BatchID', 'FileName' ]:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else :
        meta['LdmxImage'] = None
        logger.debug("Not finding a site (RTE) singularity image used for this job, setting LdmxImage: None")
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()

    #image dependency metadata

    #first check if there is a json to pull from
    if imageMeta :
        # there needs to somehow be an intermediate step here, 
        # fn case there is no structure like imageMeta[0] 
        if 'Config' in imageMeta[0] :  
            if 'Labels' in imageMeta[0]['Config'] :
                for key in imageMeta[0]['Config']['Labels'] :
                    #print(key)
                    val=imageMeta[0]['Config']['Labels'][key]
                    if 'opencontainers' in key : #make sure they split in the same number of strings as others
                        key=key.replace('org.opencontainers.image.ref', 'OS')
                        key=key.replace('org.opencontainers.image', 'OS')
                    key=key.replace('geant4', 'G4') #stick to previous naming convention
                    keepKey=key.split('.')[0].upper()+key.split('.')[1] #... and to naming: DEPENDENCYversion
                    meta[keepKey]=val 
                    print(keepKey, val)
            else :
                logger.info("Not finding 'Labels' in image metadata")
        else :
            logger.error("Not finding 'Config' in image metadata")

    else :
        print("no image metadata found, pulling info from config")
        #if not, set up the old way
        #start by setting up defaults 
        meta['G4version']='10.2.3_v0.4'
        meta['ROOTversion']='6.22.00' 
        meta['ONNXversion']='1.3.0'
        meta['XERCESversion']='3.2.3'
        meta['OSname']='UBUNTU'
        meta['OSversion']='18.04'
        for fromconf in ['G4version', 'ROOTversion', 'ONNXversion', 'XERCESversion', 'OSversion', 'OSname' ]:
            if fromconf in conf_dict :
                meta[fromconf] = conf_dict[fromconf] 

    # we want the image to end up in... :
    # user case -- user.$USER.image:myImageName.sif
    # production case -- prod.image:ldmx-pro....
    #
    #meta['UserID'] = "user."+os.environ['USER'] if os.environ['USER']!='admin' else "prod"
    meta['Scope'] = meta['UserID']+".image"
    if ".sif" not in meta['FileName'] : #make sure the extension is there
        meta['FileName'] =   meta['FileName']+".sif" 
    meta['name'] =   meta['FileName'] #if os.environ['USER']!='admin' else image 

    # Check output file actually exists, either under the right name already, or we can rename it 
    if not os.path.exists( meta['name'] ):
        if not os.path.exists( os.environ['OUTPUTDATAFILE']+'.sif' ) : 
            if not os.path.exists( os.environ['OUTPUTDATAFILE'] ) :
                logger.error('No output image named '+os.environ['OUTPUTDATAFILE']+'(.sif)'+' exists!')
                sys.exit(1)
            else :
                os.system('mv '+os.environ['OUTPUTDATAFILE']+' '+meta['name'])
        else :
            os.system('mv '+os.environ['OUTPUTDATAFILE']+'.sif '+ meta['name'])

    conf_dict['FileName'] = meta['name']
    logger.info('Shipping meta with IsImage={IsImage} to set_remote_output() '.format(**meta)) 
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/{Scope}/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        sys.exit(1)

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta



def collect_madgraph_meta( conf_dict):

    meta = {}
    meta['IsSimulation'] = True
    # madgraph library generation specifics 
    for fromconf in ['APrimeMass', 'NumberOfEvents', 'runNumber', 'IncidentEnergies', 'IsEventLibrary', 'BeamEnergy']:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # rucio specifics
    for fromconf in ['Scope', 'SampleId', 'BatchID', 'PhysicsProcess']:
        meta[fromconf] = conf_dict[fromconf] if fromconf in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else:
        meta['LdmxImage'] = None
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()

    # the job run in the image sets up the output name like this:
    mgOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta)
    # just add the tid for our purposes 
    uniqueOutName = 'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    # Check output file actually exists
    if not os.path.exists( mgOutName ) : #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}.tar.gz'.format(**meta) ):
        logger.error('Output tarball does not exist!')
        sys.exit(1)

    meta['name'] = uniqueOutName #'LDMX_W_UndecayedAP_mA_{APrimeMass}_run_{runNumber}_t{FileCreationTime}.tar.gz'.format(**meta)
    conf_dict['FileName'] = meta['name']
    os.system('mv '+mgOutName+' '+uniqueOutName)
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/lheFiles/{Scope}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        sys.exit(1)

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta


def collect_meta(conf_dict, json_file):

    logger.info("Running simulation job metadata collection")
    meta = collect_from_json(json_file, conf_dict)
    meta['IsSimulation'] = True

    # conf
    for fromconf in ['Scope', 'BatchID', 'PhysicsProcess', 'DetectorVersion', 'ElectronNumber', 'BeamEnergy']:
        try : 
            if not fromconf in meta :
                meta[fromconf] = conf_dict[fromconf] #if fromconf in conf_dict else None
        except Exception as e:
            logger.error('Failed to get mandatory key {} from job submission config: {}'.format(fromconf, str(e)))
            return meta
    if not 'BeamEnergy' in meta and 'BeamEnergy' in conf_dict : 
        meta['BeamEnergy'] = conf_dict['BeamEnergy']
        #else rely on it being copied..?
    if not 'SampleId' in meta :  #allow this to no longer being explicitly set, but compiled from the rest 
        meta['SampleId'] = 'v{}-{}GeV-{}e-{}'.format(meta['DetectorVersion'], meta['BeamEnergy'], meta['ElectronNumber'], meta['PhysicsProcess'])
    if not 'RunNumber' in meta and 'runNumber' in conf_dict :
        meta['RunNumber'] = conf_dict['runNumber']
    if not 'RandomSeed1' in meta and 'RandomSeed1' in conf_dict :
        meta['RandomSeed1'] = conf_dict['RandomSeed1']
    if not 'RandomSeed2' in meta and 'RandomSeed2' in conf_dict :
        meta['RandomSeed2'] = conf_dict['RandomSeed2']
    if ( not 'NumberOfEvents' in meta or meta['NumberOfEvents']<=0 ) and 'NumberOfEvents' in conf_dict :
        meta['NumberOfEvents'] = conf_dict['NumberOfEvents']
  
    meta['MagneticFieldmap'] = conf_dict['FieldMap'] if 'FieldMap' in conf_dict else None
    # env
    if 'ACCOUNTING_WN_INSTANCE' in os.environ:
        meta['LdmxImage'] = os.environ['ACCOUNTING_WN_INSTANCE']
    elif 'SINGULARITY_IMAGE' in os.environ:
        meta['LdmxImage'] = os.environ['SINGULARITY_IMAGE'].split('/')[-1]
    else:
        meta['LdmxImage'] = None
    meta['ARCCEJobID'] = os.environ['GRID_GLOBAL_JOBID'].split('/')[-1] if 'GRID_GLOBAL_JOBID' in os.environ else None
    meta['FileCreationTime'] = int(time.time())
    meta['Walltime'] = meta['FileCreationTime'] - job_starttime()


    # Check output file actually exists
    if not os.path.exists(conf_dict.get('FileName', '')):
        logger.error('Output file {} does not exist!'.format(conf_dict.get('FileName', '')))
        return meta
    if "hist_" in conf_dict.get('FileName') :
        meta['name'] = 'hist_{SampleId}_run{RunNumber}_t{FileCreationTime}.root'.format(**meta)
        meta['IsHistograms'] = True
        #consider setting this. don't want to confuse this with thinking it might be data though
        #meta['IsSimulation'] = False 
    else :
        meta['name'] = 'mc_{SampleId}_run{RunNumber}_t{FileCreationTime}.root'.format(**meta)
    set_remote_output(conf_dict, meta)
    if os.environ.get('KEEP_LOCAL_COPY'):
        data_location = os.environ['LDMX_STORAGE_BASE']
        data_location += '/ldmx/mc-data/{Scope}/v{DetectorVersion}/{BeamEnergy}GeV/{BatchID}/{name}'.format(**meta)
        meta['local_replica'] = data_location
        if 'DataLocation' in meta:
            meta['DataLocation'] = ','.join([meta['DataLocation'], data_location])
        else:
            meta['DataLocation'] = data_location

    if not meta.get('DataLocation'):
        logger.error('No local or remote output location for output file, file will not be registered in Rucio')
        return meta

    # Rucio metadata
    meta['scope'] = meta['Scope']
    meta['datasetscope'] = meta['Scope']
    meta['datasetname'] = meta['BatchID']
    meta['containerscope'] = meta['Scope']
    meta['containername'] = meta['SampleId']

    meta['bytes'] = os.stat(conf_dict['FileName']).st_size
    (meta['md5'], meta['adler32']) = calculate_md5_adler32_checksum(conf_dict['FileName'])

    return meta

def combine_meta( oldMeta, newMeta):
    # note: prinout level debug (here and below). default logger level is info, which hides this printout. 
    logger.debug('This should be input metadata:  {}'.format(oldMeta))

    metaOut={}
    #intialise all keys with values as pulled from the input file metadata
    inputMeta= (json.loads(oldMeta)).get("inputMeta")

    logger.debug('This should be copied metadata:  {}'.format(inputMeta))

    for key in inputMeta : 
        metaOut[key] = inputMeta[key]
        # special cases: singularity image used for input file is very important. make a new key with that
        # similarly, when continously reprocessing, need to keep track of what the input file was 
        if key == "InputFile" or key == "LdmxImage":
            if "EarlierStep"+key+"s"in metaOut :
                metaOut["EarlierStep"+key+"s"]+=", "+inputMeta[key]
            else :
                metaOut["EarlierStep"+key+"s"]=inputMeta[key]


    logger.info('This should be the current job metadata:  {}'.format(newMeta))

    #overwrite anything that has been updated
    for key in newMeta:
        metaOut[key] = newMeta[key]

    #here: if we're combining input files, the old number of events from them should be multiplied 
    if metaOut.get("NumberofEvents") :
        nEv=float(metaOut.get("NumberofEvents"))
        if metaOut.get("NumberInputFiles") :
            nFiles=int(newMeta.get("NumberInputFiles"))
            metaOut["CombinedNumberOfEvents"] = nEv*nFiles

    logger.debug('Final metadata:  {}'.format(metaOut))


    return metaOut 
    
# deprecated 
def combine_meta_fromFile( oldMetaFile, newMeta):
    metaOut={}
    #intialise all keys with values as pulled from the input file metadata
    with open(oldMetaFile, 'r') as meta_f:
        for contents in meta_f:
            contents=contents.replace("{","")
            contents=contents.replace("}","")
            #        print("Opened input metadata file")
            #        metaOut = json.load( meta_f )
            for line in contents.split(',') :
#                print line
                #            for line in contents[0]:
                line=line.replace("\"", "")
                line=line.replace(" ", "")
                kv = line.split(':', 2)
                if len(kv) != 2:
                    logger.error('Malformed %s line: %s', oldMetaFile, line)
                    continue
                metaOut[kv[0]] = kv[1].strip()
                #print (kv[0])
                #print (metaOut[kv[0]])
#    print ("Old meta")
#    json.dumps( metaOut, indent = 2, sort_keys=True  )
#    print ("\n\n")
#    print ("New meta")
#    json.dumps( newMeta, indent = 2, sort_keys=True  )
#    print ("\n\n")

    #overwrite anything that has been updated
    for key in newMeta:
        metaOut[key] = newMeta[key]
        print (key+"   "+str(metaOut[key]))
    print ("Combined meta")
    logger.debug(json.dumps( metaOut, indent = 2, sort_keys=True  ) )
    print ("\n\n")

    return metaOut 
    


def get_parser():
    parser = argparse.ArgumentParser(description='LDMX Production Simulation Helper')
    parser.add_argument('-d', '--debugLevel', action='store', default='INFO',
                        choices=['CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'],
                        help='verbosity level (default is %(default)s)')
    parser.add_argument('-c', '--config', action='store', default='ldmxjob.config',
                        help='LDMX Production simulation job config file')
    parser.add_argument('-t', '--template', action='store', default='ldmxsim.mac.template',
                        help='LDMX Production simulation macro-definition file template')
    parser.add_argument('-m', '--metaDump', action='store', default='parameterDump.json',
                        help='LDMX Production simulation parameter dump JSON file')
    parser.add_argument('-a', '--apptainerMeta', action='store',  default='', #'apptainerInspectOutput.json',
                        help='LDMX Production image metadata dump JSON file')
    parser.add_argument('-i', '--inputMeta', action='store', default='', #'inputMeta.json',
                        help='Retrieved Rucio metadata JSON file (associated with job input file)')
    parser.add_argument('-j', '--json-metadata', action='store', default='rucio.metadata',
                        help='LDMX Production simulation JSON metadata file')
    parser.add_argument('-I', '--makeImage', action='store_true', default=False,
                        help='Boolean flag to indicate a singularity image build job')

    parser.add_argument('action', choices=['init', 'copy-local', 'collect-metadata', 'collect-metadata-madgraph', 'collect-image-metadata', 'test'],
                        help='Helper action to perform')
    return parser


if __name__ == '__main__':
    # parse arguments
    cmd_args = get_parser().parse_args()
    loglevel = getattr(logging, cmd_args.debugLevel, 30)
    logger.setLevel(loglevel)

#    makeImage=cmd_args.makeImage #False 
    #if cmd_args.makeImage : 
    #    makeImage=True 
    # config is parsed the same way for any action... except image building which is very different 
    # if running an image building job, rather than production
    if cmd_args.makeImage : 
        logger.debug("Running config parsing for image building")
        conf_dict = parse_ldmx_imagebuild_config(cmd_args.config)
    else :
        conf_dict = parse_ldmx_config(cmd_args.config)

    # metadata extraction from job parameter dump: note, in local test mode, we pull input metadata from a file 
    if cmd_args.action == 'test' :
        meta = collect_from_json( cmd_args.metaDump, conf_dict )
        if cmd_args.inputMeta :
            print("Running combine_meta with "+cmd_args.inputMeta )
            with open(cmd_args.inputMeta, 'r') as meta_f :
                inMeta=(json.load(meta_f)).get("inputMeta")
                #inMeta has to be passed as a dict
                meta=combine_meta( json.dumps(inMeta), meta )
        if cmd_args.apptainerMeta :
            print("Getting image metadata from "+cmd_args.apptainerMeta )
            with open(cmd_args.apptainerMeta, 'r') as meta_f :
                inMeta=json.load(meta_f)
                logger.info(json.dumps(inMeta, indent = 2 ))
                #inMeta has to be passed as a dict
                meta=collect_image_meta( meta, inMeta) #json.dumps(apptainerMeta) )
            #meta=collect_image_meta( meta, json.dumps(cmd_args.apptainerMeta) )
            
        #print result to screen 
        json.dumps( meta, indent = 2, sort_keys=True )
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump( meta, meta_f, sort_keys=True )
    elif cmd_args.action == 'init':
        # store job start time
        job_starttime()
        # print values for bash eval
        print_eval(conf_dict, cmd_args.makeImage)
    elif cmd_args.action == 'copy-local':
        if 'InputDataLocationLocalRSE' in conf_dict :
            if not conf_dict['InputDataLocationLocalRSE'].split(",")[0] == 'None'  :
                get_local_copy( conf_dict )
# turns out this is not needed
#        if 'PileupLocationLocal' in conf_dict :
#            get_pileup_file( conf_dict )
    
    elif cmd_args.action == 'collect-metadata-madgraph':
        meta = collect_madgraph_meta(conf_dict)
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)

    elif cmd_args.action == 'collect-image-metadata' :
        logger.info("Running image metadata collection")
        if cmd_args.apptainerMeta :
            with open(cmd_args.apptainerMeta, 'r') as meta_f :
                #inMeta=json.load(meta_f)
                inMeta=json.loads(meta_f.read())
                #inMeta=(json.load(meta_f)).get("apptainerMeta")
                logger.debug(json.dumps(inMeta, indent = 2 ))
                #inMeta has to be passed as a dict
                meta=collect_image_meta(conf_dict, inMeta) #json.dumps(apptainerMeta) )
            #meta = collect_image_meta(conf_dict, cmd_args.apptainerMeta)
        else :
            meta=collect_image_meta(conf_dict, '')

        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)
            
    elif cmd_args.action == 'collect-metadata':
        meta = collect_meta(conf_dict, cmd_args.metaDump)
        if 'local_replica' in meta:
            print('export FINALOUTPUTFILE="{local_replica}"'.format(**meta))

        if 'PileupFile' in conf_dict :
            #pull the pileup file name from the job meta
            meta['PileupFile'] = conf_dict.get('PileupFile')

        if 'InputMetadata' in conf_dict :
            #first, make sure to copy over the input file name to the output meta data 
            meta['InputFile'] = conf_dict.get('InputFile')
            # combine the current job's metadata (meta) with the old one (inputMeta)
            meta=combine_meta( conf_dict.get('InputMetadata'), meta )
            #meta=combine_meta( (conf_dict.get('InputMetadata')).get("inputMeta"), meta )
        with open(cmd_args.json_metadata, 'w') as meta_f:
            json.dump(meta, meta_f)


